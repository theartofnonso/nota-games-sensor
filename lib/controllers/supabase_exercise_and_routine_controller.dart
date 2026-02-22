import 'dart:async';

import 'package:collection/collection.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';
import 'package:trainware/extensions/datetime/datetime_extension.dart';
import 'package:trainware/offline_first/routine_log_sync_service.dart';
import 'package:trainware/offline_first/routine_plan_offline_repository.dart';
import 'package:trainware/offline_first/routine_template_offline_repository.dart';
import 'package:trainware/repositories/supabase/supabase_routine_log_repository.dart';
import 'package:uuid/uuid.dart';

import '../dtos/appsync/exercise_dto.dart';
import '../dtos/appsync/routine_log_dto.dart';
import '../dtos/appsync/routine_plan_dto.dart';
import '../dtos/appsync/routine_template_dto.dart';
import '../dtos/challenges/exercise_challenge_dto.dart';
import '../dtos/set_dtos/set_dto.dart';
import '../enums/exercise_type_enums.dart';
import '../logger.dart';
import '../repositories/supabase/supabase_routine_plan_repository.dart';
import '../repositories/supabase/supabase_routine_template_repository.dart';
import '../utils/notifications_utils.dart';
import '../utils/routine_utils.dart';
import 'access_controller.dart';
import '../app_flavor.dart';
import '../services/fcm_push_service.dart';

class SupabaseExerciseAndRoutineController extends ChangeNotifier {
  bool isLoading = false;
  String errorMessage = '';
  final logger = getLogger(className: "SupabaseExerciseAndRoutineController");

  late SupabaseRoutineTemplateRepository _templateRepository;
  late SupabaseRoutinePlanRepository _planRepository;
  late SupabaseRoutineLogRepository _logRepository;
  late OfflineRoutineTemplateRepository _offlineTemplateRepository;
  late OfflineRoutinePlanRepository _offlinePlanRepository;
  late OfflineRoutineLogRepository _offlineLogRepository;
  Future<void>? _syncRoutineInFlight;
  List<ExerciseDto> _exercises = const [];
  List<RoutineTemplateDto> _overrideTemplates = const [];
  List<RoutinePlanDto> _overridePlans = const [];
  List<RoutineLogDto> _overrideLogs = const [];
  List<ExerciseChallengeDto> _overrideChallenges = const [];
  List<ExerciseChallengeDto> _clientChallenges = const [];
  final ClientOverrideController accessController;

  SupabaseExerciseAndRoutineController({
    required SupabaseRoutineTemplateRepository templateRepository,
    required SupabaseRoutinePlanRepository planRepository,
    required SupabaseRoutineLogRepository logRepository,
    required this.accessController,
  }) {
    _templateRepository = templateRepository;
    _planRepository = planRepository;
    _logRepository = logRepository;
    _offlineTemplateRepository =
        OfflineRoutineTemplateRepository(remoteRepository: _templateRepository);
    _offlinePlanRepository =
        OfflineRoutinePlanRepository(remoteRepository: _planRepository);
    _offlineLogRepository =
        OfflineRoutineLogRepository(remoteRepository: _logRepository);
  }

  UnmodifiableListView<ExerciseDto> get exercises =>
      UnmodifiableListView(_exercises);

  UnmodifiableListView<RoutineTemplateDto> get templates =>
      UnmodifiableListView(
        accessController.hasSelectedClient
            ? _overrideTemplates
            : (AppConfig.isCoach
                ? const []
                : _offlineTemplateRepository.offlineTemplates),
      );

  UnmodifiableListView<RoutinePlanDto> get plans => UnmodifiableListView(
        accessController.hasSelectedClient
            ? _overridePlans
            : (AppConfig.isCoach
                ? const []
                : _offlinePlanRepository.offlinePlans),
      );

  /// Offline-first view of routine logs backed by local cache and sync engine.
  UnmodifiableListView<RoutineLogDto> get logs => UnmodifiableListView(
        accessController.hasSelectedClient
            ? _overrideLogs
            : (AppConfig.isCoach
                ? const []
                : _offlineLogRepository.offlineLogs),
      );

  /// Direct view of logs loaded from Supabase (used internally by the
  /// offline sync engine and for debugging; prefer [logs] in the UI).
  UnmodifiableListView<RoutineLogDto> get remoteLogs => _logRepository.logs;
  bool get isCoach => AppConfig.isCoach;
  String? get activeUserId =>
      accessController.selectedClientId ??
      Supabase.instance.client.auth.currentUser?.id;

  UnmodifiableListView<ExerciseChallengeDto> get exerciseChallenges =>
      UnmodifiableListView(
        accessController.hasSelectedClient
            ? _overrideChallenges
            : (AppConfig.isCoach ? const [] : _clientChallenges),
      );

  UnmodifiableMapView<String, List<ExerciseLogDto>>
      get exerciseLogsByExerciseId =>
          UnmodifiableMapView(groupExerciseLogsByExerciseId(routineLogs: logs));

  /// Exercises that appear in logs, ordered by most recent use (newest first).
  /// Used by the exercise library to show a "From your logs" section.
  List<ExerciseDto> get exercisesFromLogsOrderedByRecency {
    final byId = <String, ({ExerciseDto exercise, DateTime lastUsed})>{};
    for (final log in logs) {
      for (final exLog in log.exerciseLogs) {
        final ex = exLog.exercise;
        final existing = byId[ex.id];
        if (existing == null || log.startTime.isAfter(existing.lastUsed)) {
          byId[ex.id] = (exercise: ex, lastUsed: log.startTime);
        }
      }
    }
    final list = byId.values.toList();
    list.sort((a, b) => b.lastUsed.compareTo(a.lastUsed));
    return list.map((e) => e.exercise).toList();
  }

  bool _blockIfClientMode() {
    if (!accessController.hasSelectedClient) {
      return false;
    }
    errorMessage = "Client mode is read-only.";
    notifyListeners();
    return true;
  }

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
      await loadExerciseCatalog();
      if (accessController.hasSelectedClient &&
          accessController.selectedClientId != null) {
        await _loadRemoteForClient(accessController.selectedClientId!);
        notifyListeners();
        return;
      }
      if (AppConfig.isCoach) {
        _overrideTemplates = const [];
        _overridePlans = const [];
        _overrideLogs = const [];
        _overrideChallenges = const [];
        notifyListeners();
        return;
      }
      // Load cached data first so they are available immediately in offline mode.
      await _offlineTemplateRepository.loadFromCache();
      await _offlinePlanRepository.loadFromCache();
      await _offlineLogRepository.loadFromCache();
      await _loadChallengesForClient(activeUserId);
      // Keep the offline caches and Supabase in sync using last-write-wins.
      await syncRoutineLogs();

      // Schedule training reminders based on historic log data
      if (logs.isNotEmpty) {
        await schedulePreferredTrainingReminders(logs: logs);
      }

      notifyListeners();
    } catch (e) {
      logger.e("Error loading user data", error: e);
      rethrow;
    }
  }

  /// Loads the canonical exercise catalog from Supabase `exercises`.
  /// This is the source used by the exercise library and relational reads.
  Future<void> loadExerciseCatalog({bool force = false}) async {
    if (!force && _exercises.isNotEmpty) return;
    try {
      final response = await Supabase.instance.client
          .from('exercises')
          .select('id,name,type')
          .order('name', ascending: true);
      final rows = response as List<dynamic>;
      final loaded = rows
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map((json) {
            final parsedType = ExerciseType.fromString(
              json['type'] as String? ?? 'NO',
            );
            return ExerciseDto(
              id: json['id'] as String? ?? '',
              name: json['name'] as String? ?? '',
              // Keep catalog exercises untyped by default; the editor flow asks
              // how to log (weights/reps/duration) when adding to a routine.
              type: parsedType,
              notes: '',
              isSystem: true,
            );
          })
          .where((e) => e.id.isNotEmpty && e.name.isNotEmpty)
          .toList();
      _exercises = loaded;
    } catch (e) {
      logger.w('Failed to load exercise catalog from Supabase: $e');
    }
  }

  /// Manually trigger a routine log sync (e.g. on pull-to-refresh or
  /// connectivity change).
  Future<void> syncRoutineLogs() async {
    if (_syncRoutineInFlight != null) {
      await _syncRoutineInFlight;
      return;
    }

    if (accessController.hasSelectedClient || AppConfig.isCoach) {
      return;
    }
    _syncRoutineInFlight = () async {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.last == ConnectivityResult.none) {
        logger.w("Sync skipped: offline/no connectivity");
        return;
      }

      await Future.wait([
        _offlineTemplateRepository.syncNow(),
        _offlinePlanRepository.syncNow(),
        _offlineLogRepository.syncNow(),
      ]);
      notifyListeners();
    }();

    try {
      await _syncRoutineInFlight;
    } finally {
      _syncRoutineInFlight = null;
    }
  }

  /// Plans

  Future<RoutinePlanDto?> savePlan({required RoutinePlanDto planDto}) async {
    if (accessController.hasSelectedClient) {
      isLoading = true;
      RoutinePlanDto? result;
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) {
          errorMessage = "Please sign in to continue.";
          notifyListeners();
          return null;
        }
        final id = planDto.id.isEmpty ? const Uuid().v4() : planDto.id;
        final planWithId = planDto.copyWith(
          id: id,
          clientId: accessController.selectedClientId,
        );
        final json = planWithId.toJson();
        json['owner'] = userId;
        await Supabase.instance.client.from('routine_plans').upsert(json);
        await _loadRemoteForClient(accessController.selectedClientId!);
        result = planWithId;
      } catch (e) {
        errorMessage = "Oops! Something went wrong. Please try again later.";
        logger.e("Error saving client plan", error: e);
      } finally {
        isLoading = false;
        errorMessage = "";
        notifyListeners();
      }
      return result;
    }
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
    final isClientMode = accessController.hasSelectedClient;
    if (!isClientMode && plan.isSystemPlan) {
      errorMessage = "System plans cannot be edited.";
      logger.w("Attempted to update system plan: ${plan.id}");
      notifyListeners();
      return;
    }
    if (isClientMode) {
      isLoading = true;
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) {
          errorMessage = "Please sign in to continue.";
          notifyListeners();
          return;
        }
        final updatedPlan =
            plan.copyWith(clientId: accessController.selectedClientId);
        final json = updatedPlan.toJson();
        json['owner'] = userId;
        await Supabase.instance.client.from('routine_plans').upsert(json);
        await _loadRemoteForClient(accessController.selectedClientId!);
      } catch (e) {
        errorMessage = "Oops! Something went wrong. Please try again later.";
        logger.e("Error updating client plan", error: e);
      } finally {
        isLoading = false;
        errorMessage = "";
        notifyListeners();
      }
      return;
    }

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
    final isClientMode = accessController.hasSelectedClient;
    if (!isClientMode && plan.isSystemPlan) {
      errorMessage = "System plans cannot be deleted.";
      logger.w("Attempted to delete system plan: ${plan.id}");
      notifyListeners();
      return;
    }

    if (isClientMode) {
      isLoading = true;
      try {
        await Supabase.instance.client
            .from('routine_plans')
            .delete()
            .eq('id', plan.id);
        await _loadRemoteForClient(accessController.selectedClientId!);
      } catch (e) {
        errorMessage = "Oops! Something went wrong. Please try again later.";
        logger.e("Error deleting client plan", error: e);
      } finally {
        isLoading = false;
        errorMessage = "";
        notifyListeners();
      }
      return;
    }

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
    if (accessController.hasSelectedClient) {
      isLoading = true;
      RoutineTemplateDto? result;
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) {
          errorMessage = "Please sign in to continue.";
          notifyListeners();
          return null;
        }
        final id = templateDto.id.isEmpty ? const Uuid().v4() : templateDto.id;
        final templateWithId = templateDto.copyWith(
          id: id,
          clientId: accessController.selectedClientId,
        );
        final json = templateWithId.toJson();
        json['owner'] = userId;
        await Supabase.instance.client.from('routine_templates').upsert(json);
        await _loadRemoteForClient(accessController.selectedClientId!);
        result = templateWithId;
      } catch (e) {
        errorMessage = "Oops! Something went wrong. Please try again later.";
        logger.e("Error saving client template", error: e);
      } finally {
        isLoading = false;
        errorMessage = "";
        notifyListeners();
      }
      return result;
    }
    // Check if template belongs to a system plan
    final plan = planWhere(id: templateDto.planId);
    if (plan?.isSystemPlan ?? false) {
      errorMessage = "Cannot add workouts to system plans.";
      logger.w(
          "Attempted to save template to system plan: ${templateDto.planId}");
      notifyListeners();
      return null;
    }

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
    final isClientMode = accessController.hasSelectedClient;
    if (!isClientMode) {
      final plan = planWhere(id: template.planId);
      if (plan?.isSystemPlan ?? false) {
        errorMessage = "Templates from system plans cannot be edited.";
        logger
            .w("Attempted to update template from system plan: ${template.id}");
        notifyListeners();
        return;
      }
    }

    if (isClientMode) {
      isLoading = true;
      try {
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) {
          errorMessage = "Please sign in to continue.";
          notifyListeners();
          return;
        }
        final updatedTemplate =
            template.copyWith(clientId: accessController.selectedClientId);
        final json = updatedTemplate.toJson();
        json['owner'] = userId;
        await Supabase.instance.client.from('routine_templates').upsert(json);
        await _loadRemoteForClient(accessController.selectedClientId!);
      } catch (e) {
        errorMessage = "Oops! Something went wrong. Please try again later.";
        logger.e("Error updating client template", error: e);
      } finally {
        isLoading = false;
        errorMessage = "";
        notifyListeners();
      }
      return;
    }

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
    final isClientMode = accessController.hasSelectedClient;
    if (!isClientMode) {
      final plan = planWhere(id: template.planId);
      if (plan?.isSystemPlan ?? false) {
        errorMessage = "Templates from system plans cannot be deleted.";
        logger
            .w("Attempted to delete template from system plan: ${template.id}");
        notifyListeners();
        return;
      }
    }

    if (isClientMode) {
      isLoading = true;
      try {
        await Supabase.instance.client
            .from('routine_templates')
            .delete()
            .eq('id', template.id);
        await _loadRemoteForClient(accessController.selectedClientId!);
      } catch (e) {
        errorMessage = "Oops! Something went wrong. Please try again later.";
        logger.e("Error deleting client template", error: e);
      } finally {
        isLoading = false;
        errorMessage = "";
        notifyListeners();
      }
      return;
    }

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
    if (_blockIfClientMode()) return null;
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
      if (logs.isNotEmpty) {
        await schedulePreferredTrainingReminders(logs: logs);
      }
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
    if (_blockIfClientMode()) return false;
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

  /// Coach-only: update the coach note for a client's session. Writes directly
  /// to Supabase (no offline layer). Refreshes client data and triggers a push
  /// to the client.
  Future<bool> updateCoachNote({
    required String logId,
    required String? note,
  }) async {
    if (!AppConfig.isCoach || !accessController.hasSelectedClient) {
      return false;
    }
    final clientId = accessController.selectedClientId!;
    isLoading = true;
    bool success = false;
    try {
      await _logRepository.updateCoachNote(logId: logId, note: note);
      await _loadRemoteForClient(clientId);
      unawaited(sendFcmNotificationCoachFeedback(
          clientUserId: clientId, logId: logId));
      success = true;
    } catch (e) {
      errorMessage = "Failed to save feedback. Please try again.";
      logger.e("Error updating coach note", error: e);
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
    if (_blockIfClientMode()) return;
    isLoading = true;
    try {
      await _offlineLogRepository.deleteLocal(log.id);
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

  List<RoutineLogDto> whereLogsIsSameMonth({required DateTime dateTime}) {
    return logs.where((log) {
      return log.startTime.year == dateTime.year &&
          log.startTime.month == dateTime.month;
    }).toList();
  }

  List<RoutineLogDto> whereLogsWithTemplateId({required String templateId}) {
    return whereLogsForTemplate(templateId: templateId);
  }

  List<SetDto> whereRecentSetsForExercise({required ExerciseDto exercise}) {
    // No past sets if type is unknown.
    if (exercise.type == ExerciseType.none) return [];

    final targetType = exercise.type;
    final exerciseLogsWithTimestamps =
        <({ExerciseLogDto log, DateTime timestamp})>[];

    for (final routineLog in logs) {
      for (final exerciseLog in routineLog.exerciseLogs) {
        // Match by exercise id AND type to avoid mixing set shapes.
        if (exerciseLog.exercise.id == exercise.id &&
            exerciseLog.exercise.type == targetType) {
          exerciseLogsWithTimestamps
              .add((log: exerciseLog, timestamp: routineLog.startTime));
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

  /// Fetches the owner (client) user id for a routine log. Used when opening a
  /// log from a notification so the coach app can load that client's data first.
  Future<String?> fetchLogOwnerId(String logId) async {
    return _logRepository.getOwnerIdForLog(logId);
  }

  /// Refreshes routine logs from the cloud for the current user (client app).
  /// Used when opening a log from a notification so the log is loaded from the
  /// server rather than relying on cache.
  Future<void> refreshRoutineLogsFromCloudForCurrentUser() async {
    await _offlineLogRepository.syncNow();
    notifyListeners();
  }

  Future<void> loadClientData({
    required String clientId,
    String? clientName,
  }) async {
    accessController.setSelectedClient(
      clientId: clientId,
      clientName: clientName,
    );
    isLoading = true;
    notifyListeners();
    try {
      await _loadRemoteForClient(clientId);
    } catch (e) {
      logger.e("Error loading client data", error: e);
      errorMessage = "Failed to load client data.";
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearSelectedClient() async {
    accessController.clearSelectedClient();
    _overrideTemplates = const [];
    _overridePlans = const [];
    _overrideLogs = const [];
    _overrideChallenges = const [];
    await initialize();
  }

  Future<void> _loadRemoteForClient(String clientId) async {
    final ownerId = Supabase.instance.client.auth.currentUser?.id;
    await _templateRepository.loadTemplates(
      ownerIdOverride: ownerId,
      clientIdOverride: clientId,
      requireOwnerAndClient: true,
    );
    _overrideTemplates = _templateRepository.templates.toList();
    await _planRepository.loadPlans(
      ownerIdOverride: ownerId,
      clientIdOverride: clientId,
      requireOwnerAndClient: true,
    );
    _overridePlans = _planRepository.plans.toList();
    await _logRepository.loadLogs(userIdOverride: clientId);
    _overrideLogs = _logRepository.logs.toList();
    await _loadChallengesForClient(clientId);
  }

  Future<void> _loadChallengesForClient(String? clientId) async {
    if (clientId == null || clientId.trim().isEmpty) return;
    try {
      final response = await Supabase.instance.client
          .from('exercise_challenges')
          .select('''
            id,
            coach_id,
            client_id,
            title,
            exercise_id,
            exercise_name,
            exercise_type,
            target_type,
            target_value,
            start_date,
            end_date,
            created_at
          ''')
          .eq('client_id', clientId)
          .order('created_at', ascending: false);
      final rows = (response as List<dynamic>)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final loaded = rows.map(ExerciseChallengeDto.fromJson).toList();
      if (accessController.hasSelectedClient) {
        _overrideChallenges = loaded;
      } else {
        _clientChallenges = loaded;
      }
    } catch (e) {
      logger.w('Failed to load exercise challenges: $e');
    }
  }

  Future<void> createExerciseChallenge({
    required String title,
    required String exerciseId,
    required String exerciseName,
    required ExerciseType exerciseType,
    required ExerciseChallengeTargetType targetType,
    required double targetValue,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final coachId = Supabase.instance.client.auth.currentUser?.id;
    final clientId = accessController.selectedClientId;
    if (coachId == null || clientId == null || clientId.trim().isEmpty) {
      errorMessage = 'Client context is required to create a challenge.';
      notifyListeners();
      return;
    }
    try {
      final challenge = ExerciseChallengeDto(
        id: '',
        coachId: coachId,
        clientId: clientId,
        title: title.trim(),
        exerciseId: exerciseId,
        exerciseName: exerciseName,
        exerciseType: exerciseType,
        targetType: targetType,
        targetValue: targetValue,
        startDate: DateUtils.dateOnly(startDate),
        endDate: DateUtils.dateOnly(endDate),
        createdAt: DateTime.now(),
      );
      final inserted = await Supabase.instance.client
          .from('exercise_challenges')
          .insert(challenge.toInsertJson())
          .select('id')
          .single();
      final createdChallengeId = inserted['id']?.toString();
      if (createdChallengeId != null && createdChallengeId.isNotEmpty) {
        unawaited(sendFcmNotificationChallengeCreated(
          challengeId: createdChallengeId,
        ));
      }
      await _loadChallengesForClient(clientId);
      notifyListeners();
    } catch (e) {
      logger.e('Error creating challenge', error: e);
      errorMessage = 'Failed to create challenge.';
      notifyListeners();
    }
  }

  Future<void> deleteExerciseChallenge({required String challengeId}) async {
    final clientId = accessController.selectedClientId ?? activeUserId;
    if (clientId == null || clientId.trim().isEmpty) return;
    try {
      await Supabase.instance.client
          .from('exercise_challenges')
          .delete()
          .eq('id', challengeId);
      await _loadChallengesForClient(clientId);
      notifyListeners();
    } catch (e) {
      logger.e('Error deleting challenge', error: e);
      errorMessage = 'Failed to delete challenge.';
      notifyListeners();
    }
  }

  ExerciseChallengeProgress progressForChallenge(
    ExerciseChallengeDto challenge, {
    DateTime? now,
  }) {
    final today = DateUtils.dateOnly(now ?? DateTime.now());
    final start = DateUtils.dateOnly(challenge.startDate);
    final end = DateUtils.dateOnly(challenge.endDate);

    final matchingLogs = logs.where((log) {
      final d = DateUtils.dateOnly(log.startTime.toLocal());
      return (d.isAtSameMomentAs(start) || d.isAfter(start)) &&
          (d.isAtSameMomentAs(end) || d.isBefore(end));
    });

    double bestValue = 0;
    for (final log in matchingLogs) {
      for (final exLog in log.exerciseLogs) {
        if (exLog.exercise.id != challenge.exerciseId) continue;
        for (final set in exLog.sets) {
          switch (challenge.targetType) {
            case ExerciseChallengeTargetType.weight:
              if (set.type != ExerciseType.weights) continue;
              final value = (set as dynamic).weight as num?;
              if (value != null) {
                bestValue = value.toDouble() > bestValue ? value.toDouble() : bestValue;
              }
              break;
            case ExerciseChallengeTargetType.reps:
              if (set.type != ExerciseType.weights &&
                  set.type != ExerciseType.bodyWeight) {
                continue;
              }
              final value = (set as dynamic).reps as num?;
              if (value != null) {
                bestValue = value.toDouble() > bestValue ? value.toDouble() : bestValue;
              }
              break;
            case ExerciseChallengeTargetType.duration:
              if (set.type != ExerciseType.duration) continue;
              final duration = (set as dynamic).duration as Duration?;
              final seconds = duration?.inSeconds.toDouble() ?? 0;
              bestValue = seconds > bestValue ? seconds : bestValue;
              break;
          }
        }
      }
    }

    final target = challenge.targetValue <= 0 ? 1 : challenge.targetValue;
    final percent = (bestValue / target).clamp(0.0, 1.0);
    final achieved = bestValue >= challenge.targetValue && challenge.targetValue > 0;

    final status = today.isBefore(start)
        ? ExerciseChallengeStatus.upcoming
        : achieved
            ? ExerciseChallengeStatus.completed
            : today.isAfter(end)
                ? ExerciseChallengeStatus.expired
                : ExerciseChallengeStatus.active;

    return ExerciseChallengeProgress(
      bestValue: bestValue,
      targetValue: challenge.targetValue,
      percent: percent,
      achieved: achieved,
      status: status,
    );
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
