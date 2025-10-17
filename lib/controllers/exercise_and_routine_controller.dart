import 'dart:collection';

import 'package:amplify_datastore/amplify_datastore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:tracker_app/dtos/exercise_log_dto.dart';
import 'package:tracker_app/enums/muscle_group_enums.dart';
import 'package:tracker_app/models/RoutineLog.dart';
import 'package:tracker_app/repositories/amplify/amplify_routine_log_repository.dart';

import '../dtos/appsync/exercise_dto.dart';
import '../dtos/appsync/routine_log_dto.dart';
import '../dtos/appsync/routine_plan_dto.dart';
import '../dtos/appsync/routine_template_dto.dart';
import '../dtos/set_dtos/set_dto.dart';
import '../logger.dart';
import '../models/Exercise.dart';
import '../models/RoutinePlan.dart';
import '../models/RoutineTemplate.dart';
import '../repositories/amplify/amplify_exercise_repository.dart';
import '../repositories/amplify/amplify_routine_plan_repository.dart';
import '../repositories/amplify/amplify_routine_template_repository.dart';

class ExerciseAndRoutineController extends ChangeNotifier {
  bool isLoading = false;
  String errorMessage = '';

  final logger = getLogger(className: "ExerciseAndRoutineController");

  late AmplifyExerciseRepository _amplifyExerciseRepository;
  late AmplifyRoutineTemplateRepository _amplifyTemplateRepository;
  late AmplifyRoutinePlanRepository _amplifyPlanRepository;
  late AmplifyRoutineLogRepository _amplifyLogRepository;

  ExerciseAndRoutineController(
      {required AmplifyExerciseRepository amplifyExerciseRepository,
      required AmplifyRoutineTemplateRepository amplifyTemplateRepository,
      required AmplifyRoutinePlanRepository amplifyPlanRepository,
      required AmplifyRoutineLogRepository amplifyLogRepository}) {
    _amplifyExerciseRepository = amplifyExerciseRepository;
    _amplifyTemplateRepository = amplifyTemplateRepository;
    _amplifyPlanRepository = amplifyPlanRepository;
    _amplifyLogRepository = amplifyLogRepository;
  }

  UnmodifiableListView<ExerciseDto> get exercises =>
      _amplifyExerciseRepository.exercises;

  UnmodifiableListView<RoutineTemplateDto> get templates =>
      _amplifyTemplateRepository.templates;

  UnmodifiableListView<RoutinePlanDto> get plans =>
      _amplifyPlanRepository.plans;

  UnmodifiableListView<RoutineLogDto> get logs => _amplifyLogRepository.logs;

  UnmodifiableMapView<String, List<ExerciseLogDto>>
      get exerciseLogsByExerciseId =>
          _amplifyLogRepository.exerciseLogsByExerciseId;

  UnmodifiableMapView<MuscleGroup, List<ExerciseLogDto>>
      get exerciseLogsByMuscleGroup =>
          _amplifyLogRepository.exerciseLogsByMuscleGroup;

  /// Exercises

  Future<void> loadLocalExercises() async {
    await _amplifyExerciseRepository.loadLocalExercises();
  }

  void streamExercises({required List<Exercise> exercises}) {
    _amplifyExerciseRepository.loadExerciseStream(exercises: exercises);
    notifyListeners();
  }

  Future<void> saveExercise({required ExerciseDto exerciseDto}) async {
    isLoading = true;
    try {
      await _amplifyExerciseRepository.saveExercise(exerciseDto: exerciseDto);
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
      await _amplifyExerciseRepository.updateExercise(exercise: exercise);
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
      await _amplifyExerciseRepository.removeExercise(exercise: exercise);
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

  void streamPlans({required List<RoutinePlan> plans}) {
    _amplifyPlanRepository.loadPlansStream(plans: plans);
    notifyListeners();
  }

  Future<RoutinePlanDto?> savePlan({required RoutinePlanDto planDto}) async {
    RoutinePlanDto? savedPlan;
    isLoading = true;
    try {
      savedPlan = await _amplifyPlanRepository.savePlan(planDto: planDto);
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error saving exercise template", error: e);
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
      await _amplifyPlanRepository.updatePlan(plan: planDto);
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error updating exercise template", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
  }

  Future<void> removePlan({required RoutinePlanDto planDto}) async {
    isLoading = true;
    try {
      await _amplifyPlanRepository.removePlan(plan: planDto);
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error removing exercise template", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
  }

  /// Templates

  void streamTemplates({required List<RoutineTemplate> templates}) {
    _amplifyTemplateRepository.loadTemplatesStream(templates: templates);
    notifyListeners();
  }

  Future<RoutineTemplateDto?> saveTemplate(
      {required RoutineTemplateDto templateDto}) async {
    RoutineTemplateDto? savedTemplate;
    isLoading = true;
    try {
      savedTemplate = await _amplifyTemplateRepository.saveTemplate(
          templateDto: templateDto);
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error saving exercise template", error: e);
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
      await _amplifyTemplateRepository.updateTemplate(template: template);
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error updating exercise template", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
  }

  Future<void> removeTemplate({required RoutineTemplateDto template}) async {
    isLoading = true;
    try {
      await _amplifyTemplateRepository.removeTemplate(template: template);
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error removing exercise template", error: e);
    } finally {
      isLoading = false;
      errorMessage = "";
      notifyListeners();
    }
  }

  /// Logs
  void streamLogs({required List<RoutineLog> logs}) {
    _amplifyLogRepository.loadLogStream(logs: logs);
    notifyListeners();
  }

  Future<RoutineLogDto?> saveLog(
      {required RoutineLogDto logDto, TemporalDateTime? datetime}) async {
    RoutineLogDto? savedLog;
    try {
      savedLog = await _amplifyLogRepository.saveLog(
          logDto: logDto, datetime: datetime);
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error saving log exercise", error: e);
    } finally {
      notifyListeners();
    }
    return savedLog;
  }

  Future<void> updateLog({required RoutineLogDto log}) async {
    try {
      await _amplifyLogRepository.updateLog(log: log);
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error update log", error: e);
    } finally {
      notifyListeners();
    }
  }

  Future<void> removeLog({required RoutineLogDto log}) async {
    try {
      await _amplifyLogRepository.removeLog(log: log);
    } catch (e) {
      errorMessage = "Oops! Something went wrong. Please try again later.";
      logger.e("Error remove log", error: e);
    } finally {
      notifyListeners();
    }
  }

  /// Logs Helper methods

  RoutineLogDto? logWhereId({required String id}) {
    return _amplifyLogRepository.logWhereId(id: id);
  }

  RoutineLogDto? whereLogIsSameDay({required DateTime dateTime}) {
    return _amplifyLogRepository.whereLogIsSameDay(dateTime: dateTime);
  }

  RoutineLogDto? whereLogIsSameMonth({required DateTime dateTime}) {
    return _amplifyLogRepository.whereLogIsSameMonth(dateTime: dateTime);
  }

  RoutineLogDto? whereLogIsSameYear({required DateTime dateTime}) {
    return _amplifyLogRepository.whereLogIsSameYear(dateTime: dateTime);
  }

  List<RoutineLogDto> whereLogsIsSameDay({required DateTime dateTime}) {
    return _amplifyLogRepository.whereLogsIsSameDay(dateTime: dateTime);
  }

  List<RoutineLogDto> whereLogsIsSameMonth({required DateTime dateTime}) {
    return _amplifyLogRepository.whereLogsIsSameMonth(dateTime: dateTime);
  }

  List<RoutineLogDto> whereLogsIsSameYear({required DateTime dateTime}) {
    return _amplifyLogRepository.whereLogsIsSameYear(dateTime: dateTime);
  }

  List<RoutineLogDto> whereLogsIsWithinRange({required DateTimeRange range}) {
    return _amplifyLogRepository.whereLogsIsWithinRange(range: range);
  }

  List<RoutineLogDto> whereLogsWithTemplateId({required String templateId}) {
    return _amplifyLogRepository.whereLogsWithTemplateId(
        templateId: templateId);
  }

  List<RoutineLogDto> whereLogsWithTemplateName(
      {required String templateName}) {
    return _amplifyLogRepository.whereLogsWithTemplateName(
        templateName: templateName);
  }

  List<RoutineLogDto> whereRoutineLogsBefore(
      {required String templateId, required DateTime datetime}) {
    return _amplifyLogRepository.whereRoutineLogsBefore(
        templateId: templateId, date: datetime);
  }

  List<ExerciseLogDto> whereExerciseLogsBefore(
      {required ExerciseDto exercise, required DateTime date}) {
    return _amplifyLogRepository.whereExerciseLogsBefore(
        exercise: exercise, date: date);
  }

  List<SetDto> whereRecentSetsForExercise({required ExerciseDto exercise}) {
    return _amplifyLogRepository.whereRecentSetsForExercise(exercise: exercise);
  }

  List<SetDto> wherePrevSetsForExercise(
      {required ExerciseDto exercise, int? take}) {
    return _amplifyLogRepository.wherePrevSetsForExercise(
        exercise: exercise, take: take);
  }

  List<SetDto> wherePrevSetsGroupForIndex(
      {required ExerciseDto exercise, required int index, int? take}) {
    return _amplifyLogRepository.wherePrevSetsGroupForIndex(
        exercise: exercise, index: index, take: take);
  }

  /// Exercise Helpers methods
  ExerciseDto? whereExercise({required String exerciseId}) {
    return _amplifyExerciseRepository.whereExercise(exerciseId: exerciseId);
  }

  /// Template Helpers methods
  RoutineTemplateDto? templateWhere({required String id}) {
    return _amplifyTemplateRepository.templateWhere(id: id);
  }

  RoutineTemplateDto? templateWherePlanId({required String id}) {
    return _amplifyTemplateRepository.templateWherePlanId(id: id);
  }

  /// Plan Helpers methods
  RoutinePlanDto? planWhere({required String id}) {
    return _amplifyPlanRepository.planWhere(id: id);
  }

  void clear() {
    _amplifyExerciseRepository.clear();
    _amplifyTemplateRepository.clear();
    _amplifyLogRepository.clear();
    notifyListeners();
  }
}
