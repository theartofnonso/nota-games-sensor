import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:tracker_app/dtos/exercise_log_dto.dart';
import 'package:tracker_app/enums/muscle_group_enums.dart';
import 'package:tracker_app/repositories/supabase/supabase_routine_log_repository.dart';

import '../dtos/appsync/exercise_dto.dart';
import '../dtos/appsync/routine_log_dto.dart';
import '../dtos/appsync/routine_plan_dto.dart';
import '../dtos/appsync/routine_template_dto.dart';
import '../dtos/set_dtos/set_dto.dart';
import '../logger.dart';
import '../repositories/supabase/supabase_exercise_repository.dart';
import '../repositories/supabase/supabase_routine_plan_repository.dart';
import '../repositories/supabase/supabase_routine_template_repository.dart';

class SupabaseExerciseAndRoutineController extends ChangeNotifier {
  bool isLoading = false;
  String errorMessage = '';

  final logger = getLogger(className: "SupabaseExerciseAndRoutineController");

  late SupabaseExerciseRepository _exerciseRepository;
  late SupabaseRoutineTemplateRepository _templateRepository;
  late SupabaseRoutinePlanRepository _planRepository;
  late SupabaseRoutineLogRepository _logRepository;

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
  }

  UnmodifiableListView<ExerciseDto> get exercises =>
      _exerciseRepository.exercises;

  UnmodifiableListView<RoutineTemplateDto> get templates =>
      _templateRepository.templates;

  UnmodifiableListView<RoutinePlanDto> get plans => _planRepository.plans;

  UnmodifiableListView<RoutineLogDto> get logs => _logRepository.logs;

  UnmodifiableMapView<String, List<ExerciseLogDto>>
      get exerciseLogsByExerciseId => _logRepository.exerciseLogsByExerciseId;

  UnmodifiableMapView<MuscleGroup, List<ExerciseLogDto>>
      get exerciseLogsByMuscleGroup => _logRepository.exerciseLogsByMuscleGroup;

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
      await Future.wait([
        _exerciseRepository.loadUserExercises(),
        _templateRepository.loadTemplates(),
        _planRepository.loadPlans(),
        _logRepository.loadLogs(),
      ]);
      notifyListeners();
    } catch (e) {
      logger.e("Error loading user data", error: e);
      rethrow;
    }
  }

  /// Exercises

  Future<void> saveExercise({required ExerciseDto exerciseDto}) async {
    isLoading = true;
    try {
      await _exerciseRepository.saveExercise(exerciseDto);
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
      await _exerciseRepository.updateExercise(exercise);
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
      await _exerciseRepository.deleteExercise(exercise);
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
    RoutinePlanDto? savedPlan;
    isLoading = true;
    try {
      savedPlan = await _planRepository.savePlan(planDto);
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error saving plan", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
    return savedPlan;
  }

  Future<void> updatePlan({required RoutinePlanDto plan}) async {
    isLoading = true;
    try {
      await _planRepository.updatePlan(plan);
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
      await _planRepository.deletePlan(plan);
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
    RoutineTemplateDto? savedTemplate;
    isLoading = true;
    try {
      savedTemplate = await _templateRepository.saveTemplate(templateDto);
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error saving template", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
    return savedTemplate;
  }

  Future<void> updateTemplate({
    required RoutineTemplateDto template,
  }) async {
    isLoading = true;
    try {
      await _templateRepository.updateTemplate(template);
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
      await _templateRepository.deleteTemplate(template);
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

  Future<RoutineLogDto?> saveLog({required RoutineLogDto logDto}) async {
    RoutineLogDto? savedLog;
    isLoading = true;
    try {
      savedLog = await _logRepository.saveLog(logDto);
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error saving log", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
    return savedLog;
  }

  Future<bool> updateLog({required RoutineLogDto log}) async {
    isLoading = true;
    bool success = false;
    try {
      await _logRepository.updateLog(log);
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

  Future<void> deleteLog({required RoutineLogDto log}) async {
    isLoading = true;
    try {
      await _logRepository.deleteLog(log);
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
    return _exerciseRepository.whereExerciseById(id);
  }

  ExerciseDto? exerciseWhereByName({required String name}) {
    return _exerciseRepository.whereExerciseByName(name);
  }

  /// Query Helpers - Plans

  RoutinePlanDto? planWhere({required String id}) {
    return _planRepository.wherePlanById(id);
  }

  /// Query Helpers - Templates

  RoutineTemplateDto? templateWhere({required String id}) {
    return _templateRepository.whereTemplateById(id);
  }

  List<RoutineTemplateDto> whereTemplatesForPlan({required String planId}) {
    return _templateRepository.whereTemplatesByPlanId(planId);
  }

  /// Query Helpers - Logs

  RoutineLogDto? logWhereId({required String id}) {
    return _logRepository.whereLogById(id);
  }

  List<RoutineLogDto> whereLogsForTemplate({required String templateId}) {
    return _logRepository.whereLogsForTemplate(templateId);
  }

  List<RoutineLogDto> whereLogsIsSameDay({required DateTime dateTime}) {
    return _logRepository.whereLogsForDate(dateTime);
  }

  List<DateTime> get allWorkoutDates => _logRepository.allWorkoutDates;

  List<ExerciseLogDto> get allExerciseLogs => _logRepository.allExerciseLogs;

  List<RoutineLogDto> get recentLogs => _logRepository.recentLogs;

  /// Exercise Log Helpers

  List<ExerciseLogDto> whereExerciseLogsForExercise({
    required ExerciseDto exercise,
  }) {
    return _logRepository.whereExerciseLogsForExercise(exercise: exercise);
  }

  Map<String, dynamic> calculatePersonalBests(ExerciseDto exercise) {
    return _logRepository.calculatePersonalBests(exercise);
  }

  /// Workout Stats

  Map<String, dynamic> get workoutStats => _logRepository.workoutStats;

  /// Get personal records for an exercise
  List<SetDto> wherePersonalRecords({required ExerciseDto exercise}) {
    final pbs = calculatePersonalBests(exercise);
    final List<SetDto> records = [];

    if (pbs['bestSet'] != null) {
      records.add(pbs['bestSet'] as SetDto);
    }

    return records;
  }

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

  List<SetDto> whereRecentSetsForExercise({required ExerciseDto exercise, String? templateId}) {
    // If templateId is provided, filter logs by template first
    List<({ExerciseLogDto log, DateTime timestamp})> exerciseLogsWithTimestamps;
    if (templateId != null && templateId.isNotEmpty) {
      // Get logs for this specific template only
      final templateLogs = whereLogsWithTemplateId(templateId: templateId);
      // Extract exercise logs for this exercise from template logs only, with timestamps
      exerciseLogsWithTimestamps = <({ExerciseLogDto log, DateTime timestamp})>[];
      for (final routineLog in templateLogs) {
        for (final exerciseLog in routineLog.exerciseLogs) {
          if (exerciseLog.exercise.id == exercise.id) {
            exerciseLogsWithTimestamps.add((
              log: exerciseLog,
              timestamp: routineLog.startTime
            ));
          }
        }
      }
    } else {
      // Original behavior: get all logs for this exercise from any template
      exerciseLogsWithTimestamps = <({ExerciseLogDto log, DateTime timestamp})>[];
      for (final routineLog in logs) {
        for (final exerciseLog in routineLog.exerciseLogs) {
          if (exerciseLog.exercise.id == exercise.id) {
            exerciseLogsWithTimestamps.add((
              log: exerciseLog,
              timestamp: routineLog.startTime
            ));
          }
        }
      }
    }
    
    if (exerciseLogsWithTimestamps.isEmpty) return [];

    // Sort by timestamp (most recent first)
    exerciseLogsWithTimestamps.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    // Get the most recent 3 exercise logs
    final recentLogs = exerciseLogsWithTimestamps.take(3).map((e) => e.log).toList();
    final allSets = <SetDto>[];
    for (final log in recentLogs) {
      allSets.addAll(log.sets);
    }
    return allSets;
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
