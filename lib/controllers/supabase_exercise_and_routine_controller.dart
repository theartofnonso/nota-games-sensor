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

  UnmodifiableListView<ExerciseDto> get exercises => _exerciseRepository.exercises;

  UnmodifiableListView<RoutineTemplateDto> get templates => _templateRepository.templates;

  UnmodifiableListView<RoutinePlanDto> get plans => _planRepository.plans;

  UnmodifiableListView<RoutineLogDto> get logs => _logRepository.logs;

  UnmodifiableMapView<String, List<ExerciseLogDto>> get exerciseLogsByExerciseId =>
      _logRepository.exerciseLogsByExerciseId;

  UnmodifiableMapView<MuscleGroup, List<ExerciseLogDto>> get exerciseLogsByMuscleGroup =>
      _logRepository.exerciseLogsByMuscleGroup;

  /// Initialization
  Future<void> initialize() async {
    isLoading = true;
    notifyListeners();

    try {
      await loadLocalExercises();
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

  Future<void> loadLocalExercises() async {
    await _exerciseRepository.loadLocalExercises();
    notifyListeners();
  }

  Future<void> saveExercise({required ExerciseDto exerciseDto}) async {
    isLoading = true;
    try {
      await _exerciseRepository.saveExercise(exerciseDto: exerciseDto);
      await _exerciseRepository.loadUserExercises();
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
      await _exerciseRepository.updateExercise(exercise: exercise);
      await _exerciseRepository.loadUserExercises();
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
      await _exerciseRepository.removeExercise(exercise: exercise);
      await _exerciseRepository.loadUserExercises();
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
      savedPlan = await _planRepository.savePlan(planDto: planDto);
      await _planRepository.loadPlans();
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

  Future<void> updatePlan({required RoutinePlanDto planDto}) async {
    isLoading = true;
    try {
      await _planRepository.updatePlan(plan: planDto);
      await _planRepository.loadPlans();
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error updating plan", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
  }

  Future<void> removePlan({required RoutinePlanDto planDto}) async {
    isLoading = true;
    try {
      await _planRepository.removePlan(plan: planDto);
      await _planRepository.loadPlans();
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error removing plan", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
  }

  /// Templates

  Future<RoutineTemplateDto?> saveTemplate({required RoutineTemplateDto templateDto}) async {
    RoutineTemplateDto? savedTemplate;
    isLoading = true;
    try {
      savedTemplate = await _templateRepository.saveTemplate(templateDto: templateDto);
      await _templateRepository.loadTemplates();
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

  Future<void> updateTemplate({required RoutineTemplateDto template}) async {
    isLoading = true;
    try {
      await _templateRepository.updateTemplate(template: template);
      await _templateRepository.loadTemplates();
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error updating template", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
  }

  Future<void> removeTemplate({required RoutineTemplateDto template}) async {
    isLoading = true;
    try {
      await _templateRepository.removeTemplate(template: template);
      await _templateRepository.loadTemplates();
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error removing template", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
  }

  /// Logs

  Future<RoutineLogDto?> saveLog({required RoutineLogDto logDto, DateTime? datetime}) async {
    RoutineLogDto? savedLog;
    try {
      savedLog = await _logRepository.saveLog(logDto: logDto, datetime: datetime);
      await _logRepository.loadLogs();
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error saving log", error: e);
    } finally {
      notifyListeners();
    }
    return savedLog;
  }

  Future<void> updateLog({required RoutineLogDto log}) async {
    try {
      await _logRepository.updateLog(log: log);
      await _logRepository.loadLogs();
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error updating log", error: e);
    } finally {
      notifyListeners();
    }
  }

  Future<void> removeLog({required RoutineLogDto log}) async {
    try {
      await _logRepository.removeLog(log: log);
      await _logRepository.loadLogs();
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error removing log", error: e);
    } finally {
      notifyListeners();
    }
  }

  /// Logs Helper methods

  RoutineLogDto? logWhereId({required String id}) {
    return _logRepository.logWhereId(id: id);
  }

  RoutineLogDto? whereLogIsSameDay({required DateTime dateTime}) {
    return _logRepository.whereLogIsSameDay(dateTime: dateTime);
  }

  RoutineLogDto? whereLogIsSameMonth({required DateTime dateTime}) {
    return _logRepository.whereLogIsSameMonth(dateTime: dateTime);
  }

  RoutineLogDto? whereLogIsSameYear({required DateTime dateTime}) {
    return _logRepository.whereLogIsSameYear(dateTime: dateTime);
  }

  List<RoutineLogDto> whereLogsIsSameDay({required DateTime dateTime}) {
    return _logRepository.whereLogsIsSameDay(dateTime: dateTime);
  }

  List<RoutineLogDto> whereLogsIsSameMonth({required DateTime dateTime}) {
    return _logRepository.whereLogsIsSameMonth(dateTime: dateTime);
  }

  List<RoutineLogDto> whereLogsIsSameYear({required DateTime dateTime}) {
    return _logRepository.whereLogsIsSameYear(dateTime: dateTime);
  }

  List<RoutineLogDto> whereLogsIsWithinRange({required DateTimeRange range}) {
    return _logRepository.whereLogsIsWithinRange(range: range);
  }

  List<RoutineLogDto> whereLogsWithTemplateId({required String templateId}) {
    return _logRepository.whereLogsWithTemplateId(templateId: templateId);
  }

  List<RoutineLogDto> whereLogsWithTemplateName({required String templateName}) {
    return _logRepository.whereLogsWithTemplateName(templateName: templateName);
  }

  List<RoutineLogDto> whereRoutineLogsBefore({required String templateId, required DateTime datetime}) {
    return _logRepository.whereRoutineLogsBefore(templateId: templateId, date: datetime);
  }

  List<ExerciseLogDto> whereExerciseLogsBefore({required ExerciseDto exercise, required DateTime date}) {
    return _logRepository.whereExerciseLogsBefore(exercise: exercise, date: date);
  }

  List<SetDto> whereRecentSetsForExercise({required ExerciseDto exercise}) {
    return _logRepository.whereRecentSetsForExercise(exercise: exercise);
  }

  List<SetDto> wherePrevSetsForExercise({required ExerciseDto exercise, int? take}) {
    return _logRepository.wherePrevSetsForExercise(exercise: exercise, take: take);
  }

  List<SetDto> wherePrevSetsGroupForIndex({required ExerciseDto exercise, required int index, int? take}) {
    return _logRepository.wherePrevSetsGroupForIndex(exercise: exercise, index: index, take: take);
  }

  /// Exercise Helper methods
  ExerciseDto? whereExercise({required String exerciseId}) {
    return _exerciseRepository.whereExercise(exerciseId: exerciseId);
  }

  /// Template Helper methods
  RoutineTemplateDto? templateWhere({required String id}) {
    return _templateRepository.templateWhere(id: id);
  }

  RoutineTemplateDto? templateWherePlanId({required String id}) {
    return _templateRepository.templateWherePlanId(id: id);
  }

  /// Plan Helper methods
  RoutinePlanDto? planWhere({required String id}) {
    return _planRepository.planWhere(id: id);
  }

  void clear() {
    _exerciseRepository.clear();
    _templateRepository.clear();
    _planRepository.clear();
    _logRepository.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    super.dispose();
  }
}

