import 'package:collection/collection.dart';
import 'package:tracker_app/enums/exercise_type_enums.dart';
import 'package:tracker_app/utils/exercise_logs_utils.dart';

import '../dtos/appsync/exercise_dto.dart';
import '../dtos/exercise_log_dto.dart';
import '../dtos/set_dtos/set_dto.dart';

class ExerciseLogRepository {
  List<ExerciseLogDto> _exerciseLogs = [];

  UnmodifiableListView<ExerciseLogDto> get exerciseLogs =>
      UnmodifiableListView(_exerciseLogs);

  void loadExerciseLogs({required List<ExerciseLogDto> exerciseLogs}) {
    _exerciseLogs = exerciseLogs;
  }

  void addExerciseLog(
      {required ExerciseDto exercise, required List<SetDto> pastSets}) {
    SetDto newSet = SetDto.newType(type: exercise.type);

    SetDto? pastSet = _wherePastSetOrNull(index: 0, pastSets: pastSets);

    if (pastSet != null) {
      newSet = pastSet.copyWith(checked: false);
    }

    /// Don't add any previous set for [ExerciseType.Duration]
    /// Duration is captured in realtime from a fresh instance
    final logToAdd = _createExerciseLog(exercise,
        pastSets: withReps(type: exercise.type) ? [newSet] : []);

    _exerciseLogs = [..._exerciseLogs, logToAdd];
  }

  void reOrderExerciseLogs({required List<ExerciseLogDto> reOrderedList}) {
    _exerciseLogs = reOrderedList;
  }

  ExerciseLogDto whereExerciseLog({required String exerciseId}) {
    return _exerciseLogs
        .firstWhere((exerciseLog) => exerciseLog.id == exerciseId);
  }

  void removeExerciseLog({required String logId}) {
    final exerciseLogIndex = _indexWhereExerciseLog(exerciseLogId: logId);
    if (exerciseLogIndex == -1) {
      return;
    }
    final logToBeRemoved = _exerciseLogs[exerciseLogIndex];

    if (logToBeRemoved.superSetId.isNotEmpty) {
      _removeSuperSet(superSetId: logToBeRemoved.superSetId);
    }

    final exerciseLogs = List.from(_exerciseLogs);

    exerciseLogs.removeAt(exerciseLogIndex);

    _exerciseLogs = [...exerciseLogs];

    _removeAllSetsForExerciseLog(exerciseLogId: logId);
  }

  void replaceExercise(
      {required String oldExerciseId,
      required ExerciseDto newExercise,
      required List<SetDto> pastSets}) {
    final oldExerciseLogIndex =
        _indexWhereExerciseLog(exerciseLogId: oldExerciseId);
    final oldExerciseLog = _whereExerciseLog(exerciseLogId: oldExerciseId);
    if (oldExerciseLogIndex == -1) {
      return;
    }

    List<ExerciseLogDto> exerciseLogs =
        List<ExerciseLogDto>.from(_exerciseLogs);

    SetDto newSet = SetDto.newType(type: newExercise.type);

    SetDto? pastSet = _wherePastSetOrNull(index: 0, pastSets: pastSets);

    if (pastSet != null) {
      newSet = pastSet.copyWith(checked: false);
    }

    /// Don't add any previous set for [ExerciseType.Duration]
    /// Duration is captured in realtime from a fresh instance
    exerciseLogs[oldExerciseLogIndex] = oldExerciseLog.copyWith(
        id: newExercise.id,
        exercise: newExercise,
        sets: withReps(type: newExercise.type) ? [newSet] : []);

    _exerciseLogs = [...exerciseLogs];
  }

  void _removeAllSetsForExerciseLog({required String exerciseLogId}) {
    // Check if exercise exists
    final exerciseLogIndex =
        _indexWhereExerciseLog(exerciseLogId: exerciseLogId);

    if (exerciseLogIndex == -1) {
      return;
    }

    // Creating a new list by copying the original list
    List<ExerciseLogDto> newExerciseLogs = _copyExerciseLogs();

    final exerciseLog = newExerciseLogs[exerciseLogIndex];
    newExerciseLogs[exerciseLogIndex] = exerciseLog.copyWith(sets: []);

    // Assign the new list to maintain immutability
    _exerciseLogs = newExerciseLogs;
  }

  void updateExerciseLogNotes(
      {required String exerciseLogId, required String value}) {
    final exerciseLogIndex =
        _indexWhereExerciseLog(exerciseLogId: exerciseLogId);

    if (exerciseLogIndex == -1) {
      return;
    }

    final exerciseLog = _exerciseLogs[exerciseLogIndex];
    _exerciseLogs[exerciseLogIndex] = exerciseLog.copyWith(notes: value);
  }

  void addSuperSets(
      {required String firstExerciseLogId,
      required String secondExerciseLogId,
      required String superSetId}) {
    final firstExerciseLogIndex =
        _indexWhereExerciseLog(exerciseLogId: firstExerciseLogId);
    final secondExerciseLogIndex =
        _indexWhereExerciseLog(exerciseLogId: secondExerciseLogId);

    if (firstExerciseLogIndex == -1 && secondExerciseLogIndex == -1) {
      return;
    }
    List<ExerciseLogDto> updatedExerciseLogs =
        List<ExerciseLogDto>.from(_exerciseLogs);

    updatedExerciseLogs[firstExerciseLogIndex] =
        updatedExerciseLogs[firstExerciseLogIndex]
            .copyWith(superSetId: superSetId);
    updatedExerciseLogs[secondExerciseLogIndex] =
        updatedExerciseLogs[secondExerciseLogIndex]
            .copyWith(superSetId: superSetId);

    final reorderedLogs =
        _reOrderSuperSets(oldExerciseLogs: updatedExerciseLogs);

    _exerciseLogs = [...reorderedLogs];
  }

  void removeSuperSet({required String superSetId}) {
    _removeSuperSet(superSetId: superSetId);
  }

  SetDto? _wherePastSetOrNull(
      {required int index, required List<SetDto> pastSets}) {
    return pastSets.firstWhereIndexedOrNull((i, set) => index == i);
  }

  void addSet({required String exerciseLogId, required List<SetDto> pastSets}) {
    int exerciseLogIndex = _indexWhereExerciseLog(exerciseLogId: exerciseLogId);

    if (exerciseLogIndex == -1) {
      return;
    }

    final sets = _setsForExerciseLog(exerciseLogId: exerciseLogId);

    int newIndex = sets.length;

    final exerciseLog = _whereExerciseLog(exerciseLogId: exerciseLogId);

    SetDto newSet = SetDto.newType(type: exerciseLog.exercise.type);

    if (exerciseLog.exercise.type != ExerciseType.duration) {
      newSet = sets.lastOrNull != null
          ? sets.last.copyWith(checked: false)
          : SetDto.newType(type: exerciseLog.exercise.type);

      SetDto? pastSet =
          _wherePastSetOrNull(index: newIndex, pastSets: pastSets);

      if (pastSet != null) {
        newSet = pastSet.copyWith(checked: false);
      }
    }

    sets.add(newSet);

    // Creating a new list by copying the original list
    List<ExerciseLogDto> newExerciseLogs = _copyExerciseLogs();

    // Updating the exerciseLog
    final newExerciseLog = newExerciseLogs[exerciseLogIndex];
    newExerciseLogs[exerciseLogIndex] = newExerciseLog.copyWith(sets: sets);

    // Assign the new list to maintain immutability
    _exerciseLogs = newExerciseLogs;
  }

  void overwriteSets(
      {required String exerciseLogId, required List<SetDto> sets}) {
    int exerciseLogIndex = _indexWhereExerciseLog(exerciseLogId: exerciseLogId);

    if (exerciseLogIndex == -1) {
      return;
    }

    // Creating a new list by copying the original list
    List<ExerciseLogDto> newExerciseLogs = _copyExerciseLogs();

    // Updating the exerciseLog
    final exerciseLog = newExerciseLogs[exerciseLogIndex];

    newExerciseLogs[exerciseLogIndex] = exerciseLog.copyWith(sets: sets);

    // Assign the new list to maintain immutability
    _exerciseLogs = newExerciseLogs;
  }

  void removeSet({required String exerciseLogId, required int index}) {
    int exerciseLogIndex = _indexWhereExerciseLog(exerciseLogId: exerciseLogId);

    if (exerciseLogIndex == -1) {
      return;
    }

    // Creating a new list by copying the original list
    List<ExerciseLogDto> newExerciseLogs = _copyExerciseLogs();

    // Updating the exerciseLog
    final exerciseLog = newExerciseLogs[exerciseLogIndex];
    final sets = exerciseLog.sets;

    // Use && to check that index is within bounds
    if (index >= 0 && index < sets.length) {
      sets.removeAt(index);
      newExerciseLogs[exerciseLogIndex] = exerciseLog.copyWith(sets: sets);

      // Assign the new list to maintain immutability
      _exerciseLogs = newExerciseLogs;
    }
  }

  void _updateSet(
      {required String exerciseLogId,
      required int index,
      required SetDto set}) {
    int exerciseLogIndex = _indexWhereExerciseLog(exerciseLogId: exerciseLogId);

    if (exerciseLogIndex == -1) {
      return;
    }

    // Creating a new list by copying the original list
    List<ExerciseLogDto> newExerciseLogs = _copyExerciseLogs();

    // Updating the exerciseLog
    final exerciseLog = newExerciseLogs[exerciseLogIndex];
    final sets = exerciseLog.sets;
    if (index >= 0 && index < sets.length) {
      sets[index] = set;

      newExerciseLogs[exerciseLogIndex] = exerciseLog.copyWith(sets: sets);

      // Assign the new list to maintain immutability
      _exerciseLogs = newExerciseLogs;
    }
  }

  void updateWeight(
      {required String exerciseLogId,
      required int index,
      required SetDto setDto}) {
    _updateSet(exerciseLogId: exerciseLogId, index: index, set: setDto);
  }

  void updateReps(
      {required String exerciseLogId,
      required int index,
      required SetDto setDto}) {
    _updateSet(exerciseLogId: exerciseLogId, index: index, set: setDto);
  }

  void updateDuration(
      {required String exerciseLogId,
      required int index,
      required SetDto setDto}) {
    _updateSet(exerciseLogId: exerciseLogId, index: index, set: setDto);
  }

  void updateSetCheck(
      {required String exerciseLogId,
      required int index,
      required SetDto setDto}) {
    _updateSet(exerciseLogId: exerciseLogId, index: index, set: setDto);
  }

  /// Helper functions

  ExerciseLogDto _createExerciseLog(ExerciseDto exercise,
      {String notes = "", List<SetDto> pastSets = const []}) {
    return ExerciseLogDto(
        id: exercise.id,
        routineLogId: "",
        superSetId: "",
        exercise: exercise,
        notes: notes,
        sets: pastSets,
        createdAt: DateTime.now());
  }

  List<ExerciseLogDto> completedExerciseLogs() {
    return _exerciseLogs.where((exercise) {
      final hasCompletedSets =
          exercise.sets.where((set) => set.checked).isNotEmpty;
      return hasCompletedSets;
    }).toList();
  }

  List<SetDto> completedSets() {
    return _exerciseLogs
        .expand((exerciseLog) => exerciseLog.sets)
        .where((set) => set.checked)
        .toList();
  }

  void _removeSuperSet({required String superSetId}) {
    // Create a new list where modifications will be made
    List<ExerciseLogDto> updatedExerciseLogs = [];

    // Iterate over the original exerciseLogs list
    for (ExerciseLogDto exerciseLog in _exerciseLogs) {
      if (exerciseLog.superSetId == superSetId) {
        // Create a new exerciseLogDto with an updated superSetId
        updatedExerciseLogs.add(exerciseLog.copyWith(superSetId: ""));
      } else {
        // Add the original exerciseLogDto to the new list
        updatedExerciseLogs.add(exerciseLog);
      }
    }

    // Update the _exerciseLogs with the new list
    _exerciseLogs = updatedExerciseLogs;
  }

  Iterable<ExerciseLogDto> _reOrderSuperSets(
      {required List<ExerciseLogDto> oldExerciseLogs}) {
    Set<ExerciseLogDto> reorderedLogs = {};
    for (final exerciseLog in oldExerciseLogs) {
      if (exerciseLog.superSetId.isEmpty) {
        reorderedLogs.add(exerciseLog);
      } else {
        final logs = oldExerciseLogs
            .where((log) => log.superSetId == exerciseLog.superSetId)
            .toList();
        reorderedLogs.addAll(logs);
        continue;
      }
    }
    return reorderedLogs;
  }

  int _indexWhereExerciseLog({required String exerciseLogId}) {
    return _exerciseLogs
        .indexWhere((exerciseLog) => exerciseLog.id == exerciseLogId);
  }

  ExerciseLogDto _whereExerciseLog({required String exerciseLogId}) {
    return _exerciseLogs
        .firstWhere((exerciseLog) => exerciseLog.id == exerciseLogId);
  }

  List<SetDto> _setsForExerciseLog({required String exerciseLogId}) {
    final exerciseLogIndex =
        _indexWhereExerciseLog(exerciseLogId: exerciseLogId);
    if (exerciseLogIndex == -1) {
      return [];
    }
    final exerciseLog = _exerciseLogs[exerciseLogIndex];
    return exerciseLog.sets;
  }

  List<ExerciseLogDto> _copyExerciseLogs() {
    return List<ExerciseLogDto>.from(_exerciseLogs);
  }

  void clear() {
    _exerciseLogs = [];
  }
}
