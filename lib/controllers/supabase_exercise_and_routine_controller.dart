import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';
import 'package:trainware/extensions/datetime/datetime_extension.dart';
import 'package:trainware/offline_first/exercise_offline_repository.dart';
import 'package:trainware/offline_first/routine_log_sync_service.dart';
import 'package:trainware/offline_first/routine_plan_offline_repository.dart';
import 'package:trainware/offline_first/routine_template_offline_repository.dart';
import 'package:trainware/repositories/supabase/supabase_routine_log_repository.dart';
import 'package:uuid/uuid.dart';

import '../dtos/appsync/exercise_dto.dart';
import '../dtos/appsync/routine_log_dto.dart';
import '../dtos/appsync/routine_plan_dto.dart';
import '../dtos/appsync/routine_template_dto.dart';
import '../dtos/set_dtos/set_dto.dart';
import '../logger.dart';
import '../repositories/supabase/supabase_exercise_repository.dart';
import '../repositories/supabase/supabase_routine_plan_repository.dart';
import '../repositories/supabase/supabase_routine_template_repository.dart';
import '../utils/notifications_utils.dart';
import '../utils/routine_utils.dart';

class SupabaseExerciseAndRoutineController extends ChangeNotifier {
  bool isLoading = false;
  String errorMessage = '';

  final logger = getLogger(className: "SupabaseExerciseAndRoutineController");

  late SupabaseExerciseRepository _exerciseRepository;
  late SupabaseRoutineTemplateRepository _templateRepository;
  late SupabaseRoutinePlanRepository _planRepository;
  late SupabaseRoutineLogRepository _logRepository;
  late OfflineExerciseRepository _offlineExerciseRepository;
  late OfflineRoutineTemplateRepository _offlineTemplateRepository;
  late OfflineRoutinePlanRepository _offlinePlanRepository;
  late OfflineRoutineLogRepository _offlineLogRepository;

  SupabaseExerciseAndRoutineController({
    required SupabaseExerciseRepository exerciseRepository,
    required SupabaseRoutineTemplateRepository templateRepository,
    required SupabaseRoutinePlanRepository planRepository,
    required SupabaseRoutineLogRepository logRepository,
  }) {
    _exerciseRepository = exerciseRepository;
    _templateRepository = templateRepository;
    _planRepository = planRepository;
    _logRepository = logRepository;
    _offlineExerciseRepository =
        OfflineExerciseRepository(remoteRepository: _exerciseRepository);
    _offlineTemplateRepository =
        OfflineRoutineTemplateRepository(remoteRepository: _templateRepository);
    _offlinePlanRepository =
        OfflineRoutinePlanRepository(remoteRepository: _planRepository);
    _offlineLogRepository =
        OfflineRoutineLogRepository(remoteRepository: _logRepository);
  }

  UnmodifiableListView<ExerciseDto> get exercises =>
      UnmodifiableListView(_offlineExerciseRepository.offlineExercises);

  UnmodifiableListView<RoutineTemplateDto> get templates =>
      UnmodifiableListView(_offlineTemplateRepository.offlineTemplates);

  UnmodifiableListView<RoutinePlanDto> get plans =>
      UnmodifiableListView(_offlinePlanRepository.offlinePlans);

  /// Offline-first view of routine logs backed by local cache and sync engine.
  UnmodifiableListView<RoutineLogDto> get logs =>
      UnmodifiableListView(_offlineLogRepository.offlineLogs);

  /// Direct view of logs loaded from Supabase (used internally by the
  /// offline sync engine and for debugging; prefer [logs] in the UI).
  UnmodifiableListView<RoutineLogDto> get remoteLogs => _logRepository.logs;

  UnmodifiableMapView<String, List<ExerciseLogDto>>
      get exerciseLogsByExerciseId =>
          UnmodifiableMapView(groupExerciseLogsByExerciseId(routineLogs: logs));

  /// Initialization
  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();

    try {
      await loadUserData();
    } catch (e) {
      logger.e("Error initializing controller", error: e);
      errorMessage = "Failed to initialize. Please restart the app.";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadUserData() async {
    try {
      // Load cached data first so they are available immediately in offline mode.
      await _offlineExerciseRepository.loadFromCache();
      await _offlineTemplateRepository.loadFromCache();
      await _offlinePlanRepository.loadFromCache();
      await _offlineLogRepository.loadFromCache();
      // Keep the offline caches and Supabase in sync using last-write-wins.
      await syncRoutineLogs();

      // Schedule training reminders based on historic log data
      final historicLogTimes = logs.map((log) => log.startTime).toList();
      if (historicLogTimes.isNotEmpty) {
        await schedulePreferredTrainingReminders(
            historicDateTimes: historicLogTimes);
      }

      notifyListeners();
    } catch (e) {
      logger.e("Error loading user data", error: e);
      rethrow;
    }
  }

  /// Manually trigger a routine log sync (e.g. on pull-to-refresh or
  /// connectivity change).
  Future<void> syncRoutineLogs() async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.last == ConnectivityResult.none) {
      logger.w("Sync skipped: offline/no connectivity");
      return;
    }

    await Future.wait([
      _offlineExerciseRepository.syncNow(),
      _offlineTemplateRepository.syncNow(),
      _offlinePlanRepository.syncNow(),
      _offlineLogRepository.syncNow(),
    ]);
    notifyListeners();
  }

  /// Exercises

  Future<void> saveExercise({required ExerciseDto exerciseDto}) async {
    isLoading = true;
    try {
      // Ensure new exercises have a stable client-generated ID so offline
      // storage and Supabase stay in sync.
      final id = exerciseDto.id.isEmpty ? const Uuid().v4() : exerciseDto.id;
      final exerciseWithId = exerciseDto.copyWith(id: id);

      await _offlineExerciseRepository.upsertLocal(exerciseWithId);
      // ignore: discarded_futures
      syncRoutineLogs();
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error saving exercise", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
  }

  Future<void> updateExercise({required ExerciseDto exercise}) async {
    isLoading = true;
    try {
      await _offlineExerciseRepository.upsertLocal(exercise);
      // ignore: discarded_futures
      syncRoutineLogs();
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error updating exercise", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
  }

  Future<void> removeExercise({required ExerciseDto exercise}) async {
    isLoading = true;
    try {
      await _offlineExerciseRepository.deleteLocal(exercise.id);
      // ignore: discarded_futures
      syncRoutineLogs();
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error removing exercise", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
  }

  /// Plans

  Future<RoutinePlanDto?> savePlan({required RoutinePlanDto planDto}) async {
    isLoading = true;
    RoutinePlanDto? result;
    try {
      // Generate a stable ID for new plans so they can be synced correctly.
      final id = planDto.id.isEmpty ? const Uuid().v4() : planDto.id;
      final planWithId = planDto.copyWith(id: id);

      await _offlinePlanRepository.upsertLocal(planWithId);
      // ignore: discarded_futures
      syncRoutineLogs();
      result = planWithId;
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error saving plan", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
    return result;
  }

  Future<void> updatePlan({required RoutinePlanDto plan}) async {
    isLoading = true;
    try {
      await _offlinePlanRepository.upsertLocal(plan);
      // ignore: discarded_futures
      syncRoutineLogs();
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error updating plan", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
  }

  Future<void> deletePlan({required RoutinePlanDto plan}) async {
    isLoading = true;
    try {
      await _offlinePlanRepository.deleteLocal(plan.id);
      // ignore: discarded_futures
      syncRoutineLogs();
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error deleting plan", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
  }

  /// Templates

  Future<RoutineTemplateDto?> saveTemplate({
    required RoutineTemplateDto templateDto,
  }) async {
    isLoading = true;
    RoutineTemplateDto? result;
    try {
      // Generate a stable ID for new templates so they can be synced correctly.
      final id = templateDto.id.isEmpty ? const Uuid().v4() : templateDto.id;
      final templateWithId = templateDto.copyWith(id: id);

      await _offlineTemplateRepository.upsertLocal(templateWithId);
      // ignore: discarded_futures
      syncRoutineLogs();
      result = templateWithId;
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error saving template", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
    return result;
  }

  Future<void> updateTemplate({
    required RoutineTemplateDto template,
  }) async {
    isLoading = true;
    try {
      await _offlineTemplateRepository.upsertLocal(template);
      // ignore: discarded_futures
      syncRoutineLogs();
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error updating template", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
  }

  Future<void> deleteTemplate({
    required RoutineTemplateDto template,
  }) async {
    isLoading = true;
    try {
      await _offlineTemplateRepository.deleteLocal(template.id);
      // ignore: discarded_futures
      syncRoutineLogs();
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error deleting template", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
  }

  /// Logs

  /// Local-first create: write to the offline cache, then sync to Supabase
  /// in the background using last-write-wins.
  Future<RoutineLogDto?> saveLog({required RoutineLogDto logDto}) async {
    isLoading = true;
    try {
      // Generate a stable ID if needed so we can persist locally without
      // relying on the remote database.
      final id = logDto.id.isEmpty ? const Uuid().v4() : logDto.id;

      // Ensure all nested exercise logs reference this routine log ID.
      final logWithId = logDto.copyWith(id: id);
      final updatedLog = logWithId.copyWith(
        exerciseLogs: logWithId.exerciseLogs
            .map((exerciseLog) => exerciseLog.copyWith(routineLogId: id))
            .toList(),
      );

      // Local-first write: persist to the offline repository so the workout
      // is immediately available offline and in the UI.
      await _offlineLogRepository.upsertLocal(updatedLog);

      // Best-effort background sync with Supabase. We don't await this so
      // that the UI isn't blocked by network conditions.
      // ignore: discarded_futures
      syncRoutineLogs();

      // Reschedule training reminders based on updated (offline-first) log data.
      final historicLogTimes = logs.map((log) => log.startTime).toList();
      if (historicLogTimes.isNotEmpty) {
        await schedulePreferredTrainingReminders(
            historicDateTimes: historicLogTimes);
      }
      await schedulePostWorkoutReviewReminder(
          log: updatedLog, debugDelay: const Duration(minutes: 5));
      return updatedLog;
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error saving log", error: e);
      return null;
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
  }

  /// Local-first update: modify the offline cache and then sync in the
  /// background. Callers still get a success flag but are not blocked
  /// on the network.
  Future<bool> updateLog({required RoutineLogDto log}) async {
    isLoading = true;
    bool success = false;
    try {
      await _offlineLogRepository.upsertLocal(log);

      // ignore: discarded_futures
      syncRoutineLogs();

      success = true;
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error updating log", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
    return success;
  }

  /// Local-first delete: mark/remove the log from the offline cache and
  /// then sync in the background.
  Future<void> deleteLog({required RoutineLogDto log}) async {
    isLoading = true;
    try {
      await _offlineLogRepository.deleteLocal(log.id);
      await cancelPostWorkoutReviewReminder(log.id);

      // ignore: discarded_futures
      syncRoutineLogs();
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error deleting log", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
  }

  /// Query Helpers - Exercises

  ExerciseDto? exerciseWhere({required String id}) {
    return exercises.firstWhereOrNull((exercise) => exercise.id == id);
  }

  ExerciseDto? exerciseWhereByName({required String name}) {
    return exercises.firstWhereOrNull(
      (exercise) => exercise.name.toLowerCase() == name.toLowerCase(),
    );
  }

  /// Query Helpers - Plans

  RoutinePlanDto? planWhere({required String id}) {
    return plans.firstWhereOrNull((plan) => plan.id == id);
  }

  /// Query Helpers - Templates

  RoutineTemplateDto? templateWhere({required String id}) {
    return templates.firstWhereOrNull((template) => template.id == id);
  }

  List<RoutineTemplateDto> whereTemplatesForPlan({required String planId}) {
    return templates.where((template) => template.planId == planId).toList();
  }

  /// Query Helpers - Logs

  RoutineLogDto? logWhereId({required String id}) {
    return logs.firstWhereOrNull((log) => log.id == id);
  }

  List<RoutineLogDto> whereLogsForTemplate({required String templateId}) {
    return logs.where((log) => log.templateId == templateId).toList();
  }

  List<RoutineLogDto> whereLogsIsSameDay({required DateTime dateTime}) {
    return logs
        .where((log) => log.startTime.isSameDayMonthYear(dateTime))
        .toList();
  }

  List<DateTime> get allWorkoutDates {
    final uniqueDates = <String, DateTime>{};
    for (final log in logs) {
      final dateKey = log.startTime.toIso8601String().substring(0, 10);
      uniqueDates[dateKey] = log.startTime;
    }
    return uniqueDates.values.toList();
  }

  List<ExerciseLogDto> get allExerciseLogs {
    return logs.expand((log) => log.exerciseLogs).toList();
  }

  List<RoutineLogDto> get recentLogs {
    final sorted = List<RoutineLogDto>.from(logs)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return sorted.take(10).toList();
  }

  /// Exercise Log Helpers

  List<ExerciseLogDto> whereExerciseLogsForExercise({
    required ExerciseDto exercise,
  }) {
    final matches = <ExerciseLogDto>[];
    for (final routineLog in logs) {
      for (final exerciseLog in routineLog.exerciseLogs) {
        if (exerciseLog.exercise.id == exercise.id) {
          matches.add(exerciseLog);
        }
      }
    }
    return matches;
  }

  // Personal bests removed from project

  /// Workout Stats

  Map<String, dynamic> get workoutStats {
    final totalWorkouts = logs.length;
    final totalExercises = allExerciseLogs.length;
    final totalVolume = allExerciseLogs.fold<double>(
      0,
      (sum, log) =>
          sum +
          log.sets.fold<double>(
            0,
            (setSum, set) {
              // Only weight+reps sets contribute to volume.
              // We avoid importing specific set DTO types here to keep this
              // controller decoupled; volume is computed elsewhere as well.
              try {
                final weight = (set as dynamic).weight as num?;
                final reps = (set as dynamic).reps as num?;
                if (weight != null && reps != null) {
                  return setSum + (weight * reps);
                }
              } catch (_) {
                // Non-weighted sets or unexpected types are ignored in volume.
              }
              return setSum;
            },
          ),
    );

    final avgDuration = logs.isEmpty
        ? Duration.zero
        : Duration(
            seconds: logs
                    .map((log) =>
                        log.endTime.difference(log.startTime).inSeconds)
                    .reduce((a, b) => a + b) ~/
                totalWorkouts,
          );

    return {
      'totalWorkouts': totalWorkouts,
      'totalExercises': totalExercises,
      'totalVolume': totalVolume,
      'avgDuration': avgDuration,
    };
  }

  // Personal bests removed from project

  /// Additional log helper methods
  List<RoutineLogDto> whereLogsIsWithinRange(
      {required DateTimeRange dateRange}) {
    return logs.where((log) {
      return log.startTime
              .isAfter(dateRange.start.subtract(const Duration(days: 1))) &&
          log.startTime.isBefore(dateRange.end.add(const Duration(days: 1)));
    }).toList();
  }

  List<RoutineLogDto> whereLogsIsSameMonth({required DateTime dateTime}) {
    return logs.where((log) {
      return log.startTime.year == dateTime.year &&
          log.startTime.month == dateTime.month;
    }).toList();
  }

  List<RoutineLogDto> whereLogsWithTemplateId({required String templateId}) {
    return whereLogsForTemplate(templateId: templateId);
  }

  List<ExerciseLogDto> whereExerciseLogsBefore(
      {required DateTime dateTime, required ExerciseDto exercise}) {
    final logsBeforeDate =
        logs.where((log) => log.startTime.isBefore(dateTime)).toList();
    final exerciseLogs = <ExerciseLogDto>[];
    for (final log in logsBeforeDate) {
      exerciseLogs.addAll(
          log.exerciseLogs.where((el) => el.exercise.id == exercise.id));
    }
    return exerciseLogs;
  }

  List<SetDto> whereRecentSetsForExercise(
      {required ExerciseDto exercise, String? templateId}) {
    // If templateId is provided, filter logs by template first
    List<({ExerciseLogDto log, DateTime timestamp})> exerciseLogsWithTimestamps;
    if (templateId != null && templateId.isNotEmpty) {
      // Get logs for this specific template only
      final templateLogs = whereLogsWithTemplateId(templateId: templateId);
      // Extract exercise logs for this exercise from template logs only, with timestamps
      exerciseLogsWithTimestamps =
          <({ExerciseLogDto log, DateTime timestamp})>[];
      for (final routineLog in templateLogs) {
        for (final exerciseLog in routineLog.exerciseLogs) {
          if (exerciseLog.exercise.id == exercise.id) {
            exerciseLogsWithTimestamps
                .add((log: exerciseLog, timestamp: routineLog.startTime));
          }
        }
      }
    } else {
      // Original behavior: get all logs for this exercise from any template
      exerciseLogsWithTimestamps =
          <({ExerciseLogDto log, DateTime timestamp})>[];
      for (final routineLog in logs) {
        for (final exerciseLog in routineLog.exerciseLogs) {
          if (exerciseLog.exercise.id == exercise.id) {
            exerciseLogsWithTimestamps
                .add((log: exerciseLog, timestamp: routineLog.startTime));
          }
        }
      }
    }

    if (exerciseLogsWithTimestamps.isEmpty) return [];

    // Sort by timestamp (most recent first)
    exerciseLogsWithTimestamps
        .sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Get the most recent 3 exercise logs
    final recentLogs =
        exerciseLogsWithTimestamps.take(3).map((e) => e.log).toList();
    final allSets = <SetDto>[];
    for (final log in recentLogs) {
      allSets.addAll(log.sets);
    }
    return allSets;
  }

  /// Returns the most recent [limit] exercise logs for a given exercise,
  /// ordered from most recent to oldest.
  ///
  /// Only returns one exercise log per distinct session (routineLogId),
  /// even if the same exercise appears multiple times in a session.
  List<ExerciseLogDto> whereRecentExerciseLogsForExercise({
    required ExerciseDto exercise,
    int limit = 4,
  }) {
    final matches =
        <({ExerciseLogDto log, DateTime timestamp, String? routineLogId})>[];

    for (final routineLog in logs) {
      for (final exerciseLog in routineLog.exerciseLogs) {
        if (exerciseLog.exercise.id == exercise.id) {
          matches.add((
            log: exerciseLog,
            timestamp: routineLog.startTime,
            routineLogId: routineLog.id,
          ));
        }
      }
    }

    if (matches.isEmpty) return const [];

    matches.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Group by routineLogId to ensure we only return one exercise log per session
    final seenRoutineLogIds = <String?>{};
    final distinctMatches = <ExerciseLogDto>[];

    for (final match in matches) {
      if (!seenRoutineLogIds.contains(match.routineLogId)) {
        seenRoutineLogIds.add(match.routineLogId);
        distinctMatches.add(match.log);
        if (distinctMatches.length >= limit) break;
      }
    }

    return distinctMatches;
  }

  List<SetDto> wherePrevSetsForExercise({required ExerciseDto exercise}) {
    final exerciseLogs = whereExerciseLogsForExercise(exercise: exercise);
    if (exerciseLogs.isEmpty) return [];

    final allSets = <SetDto>[];
    for (final log in exerciseLogs) {
      allSets.addAll(log.sets);
    }
    return allSets;
  }

  Future<void> removeLog({required RoutineLogDto log}) async {
    return deleteLog(log: log);
  }

  Future<void> removePlan({required RoutinePlanDto plan}) async {
    return deletePlan(plan: plan);
  }

  Future<void> removeTemplate({required RoutineTemplateDto template}) async {
    return deleteTemplate(template: template);
  }

  /// Clear all data (on logout)
  void clear() {
    isLoading = false;
    errorMessage = '';
    notifyListeners();
  }
}
