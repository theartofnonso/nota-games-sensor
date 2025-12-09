import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../dtos/appsync/exercise_dto.dart';
import '../dtos/appsync/routine_log_dto.dart';
import '../dtos/exercise_log_dto.dart';
import '../dtos/set_dtos/set_dto.dart';
import '../logger.dart';
import '../repositories/exercise_log_repository.dart';
import '../shared_prefs.dart';

class ExerciseLogController extends ChangeNotifier {
  late ExerciseLogRepository _exerciseLogRepository;

  final logger = getLogger(className: "ExerciseLogController");

  ExerciseLogController(ExerciseLogRepository exerciseLogRepository) {
    _exerciseLogRepository = exerciseLogRepository;
  }

  UnmodifiableListView<ExerciseLogDto> get exerciseLogs =>
      _exerciseLogRepository.exerciseLogs;

  RoutineLogDto? _initialRoutineLog;
  bool _shouldCacheToSharedPrefs = false;

  void loadRoutineLog(
      {required RoutineLogDto routineLog, bool shouldCache = false}) {
    _initialRoutineLog = routineLog;

    // Only enable caching if explicitly requested (for live workout sessions)
    // and if this matches the cached workout (to prevent mixing data)
    if (shouldCache) {
      final cachedLog = SharedPrefs().routineLog;
      if (cachedLog.isNotEmpty) {
        try {
          final cachedJson = jsonDecode(cachedLog);
          final cachedRoutineLog = RoutineLogDto.fromJson(json: cachedJson);
          // Only cache if we're editing the same workout that's cached
          _shouldCacheToSharedPrefs = cachedRoutineLog.id == routineLog.id;
        } catch (e) {
          // If we can't parse cached log, don't cache
          _shouldCacheToSharedPrefs = false;
        }
      } else {
        // No cached workout, enable caching for new workout
        _shouldCacheToSharedPrefs = true;
      }
    } else {
      // Not a live workout session, don't cache
      _shouldCacheToSharedPrefs = false;
    }
    _cache();
  }

  void loadExerciseLogs({required List<ExerciseLogDto> exerciseLogs}) {
    _exerciseLogRepository.loadExerciseLogs(exerciseLogs: exerciseLogs);
    // Disable caching when loading exercise logs (used for templates/past logs)
    _shouldCacheToSharedPrefs = false;
    _initialRoutineLog = null;
    logger.i("load exercise logs");
  }

  ExerciseLogDto? whereExerciseLog({required String exerciseId}) {
    return _exerciseLogRepository.whereExerciseLog(exerciseId: exerciseId);
  }

  void addExerciseLog(
      {required ExerciseDto exercise, required List<SetDto> pastSets}) {
    _exerciseLogRepository.addExerciseLog(
        exercise: exercise, pastSets: pastSets);
    _cache();
    logger.i("load exercise log: $exercise");
    notifyListeners();
  }

  void reOrderExerciseLogs({required List<ExerciseLogDto> reOrderedList}) {
    _exerciseLogRepository.reOrderExerciseLogs(reOrderedList: reOrderedList);
    _cache();
    notifyListeners();
  }

  void removeExerciseLog({required String logId}) {
    _exerciseLogRepository.removeExerciseLog(logId: logId);
    _cache();
    notifyListeners();
  }

  void replaceExerciseLog(
      {required String oldExerciseId,
      required ExerciseDto newExercise,
      required List<SetDto> pastSets}) {
    _exerciseLogRepository.replaceExercise(
        oldExerciseId: oldExerciseId,
        newExercise: newExercise,
        pastSets: pastSets);
    _cache();
    notifyListeners();
  }

  void updateExerciseLogNotes(
      {required String exerciseLogId, required String value}) {
    _exerciseLogRepository.updateExerciseLogNotes(
        exerciseLogId: exerciseLogId, value: value);
    _cache();
    notifyListeners();
  }

  void superSetExerciseLogs(
      {required String firstExerciseLogId,
      required String secondExerciseLogId,
      required String superSetId}) {
    _exerciseLogRepository.addSuperSets(
        firstExerciseLogId: firstExerciseLogId,
        secondExerciseLogId: secondExerciseLogId,
        superSetId: superSetId);
    _cache();
    notifyListeners();
  }

  void removeSuperSet({required String superSetId}) {
    _exerciseLogRepository.removeSuperSet(superSetId: superSetId);
    _cache();
    notifyListeners();
  }

  void addSet({required String exerciseLogId, required List<SetDto> pastSets}) {
    _exerciseLogRepository.addSet(
        exerciseLogId: exerciseLogId, pastSets: pastSets);
    _cache();
    notifyListeners();
  }

  void overwriteSets(
      {required String exerciseLogId, required List<SetDto> newSets}) {
    _exerciseLogRepository.overwriteSets(
        exerciseLogId: exerciseLogId, sets: newSets);
    _cache();
    notifyListeners();
  }

  void removeSetForExerciseLog(
      {required String exerciseLogId, required int index}) {
    _exerciseLogRepository.removeSet(
        exerciseLogId: exerciseLogId, index: index);
    _cache();
    notifyListeners();
  }

  void updateWeight(
      {required String exerciseLogId,
      required int index,
      required SetDto setDto}) {
    _exerciseLogRepository.updateWeight(
        exerciseLogId: exerciseLogId, index: index, setDto: setDto);
    _cache();
    notifyListeners();
  }

  void updateReps(
      {required String exerciseLogId,
      required int index,
      required SetDto setDto}) {
    _exerciseLogRepository.updateReps(
        exerciseLogId: exerciseLogId, index: index, setDto: setDto);
    _cache();
    notifyListeners();
  }

  void updateDuration(
      {required String exerciseLogId,
      required int index,
      required SetDto setDto,
      required bool notify}) {
    _exerciseLogRepository.updateDuration(
        exerciseLogId: exerciseLogId, index: index, setDto: setDto);
    _cache();
    if (notify) {
      notifyListeners();
    }
  }

  void updateSetCheck(
      {required String exerciseLogId,
      required int index,
      required SetDto setDto}) {
    _exerciseLogRepository.updateSetCheck(
        exerciseLogId: exerciseLogId, index: index, setDto: setDto);
    _cache();
    notifyListeners();
  }

  List<SetDto> completedSets() {
    return _exerciseLogRepository.completedSets();
  }

  List<ExerciseLogDto> completedExerciseLog() {
    return _exerciseLogRepository.completedExerciseLogs();
  }

  /// Clear only in-memory state. Does NOT touch the cached routineLog in SharedPrefs.
  void clearLocal() {
    _exerciseLogRepository.clear();
    _initialRoutineLog = null;
    _shouldCacheToSharedPrefs = false;
  }

  /// Clear both in-memory state and the cached pending routine log.
  /// Use this only when a session has been successfully saved/updated or explicitly discarded.
  void onClear() {
    clearLocal();
    SharedPrefs().remove(key: SharedPrefs().routineLogKey);
  }

  void _cache() {
    // Only cache if we're editing the active unsaved workout
    if (!_shouldCacheToSharedPrefs) return;

    final routineLog = _initialRoutineLog?.copyWith(
        exerciseLogs: exerciseLogs, endTime: DateTime.now());
    if (routineLog != null) {
      SharedPrefs().routineLog = jsonEncode(routineLog,
          toEncodable: (Object? value) => value is RoutineLogDto
              ? value.toJson()
              : throw UnsupportedError('Cannot convert to JSON: $value'));
    }
  }
}
