import 'package:collection/collection.dart';
import 'package:trainware/enums/exercise_type_enums.dart';
import 'package:trainware/utils/exercise_logs_utils.dart';

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
    if (exercise.type == ExerciseType.none) {
      throw const FormatException(
          'Exercise type must be selected before adding to the log');
    }

    List<SetDto> seededSets = [];
    SetDto newSet = SetDto.newType(type: exercise.type);

    SetDto? pastSet = _wherePastSetOrNull(index: 0, pastSets: pastSets);

    if (pastSet != null) {
      newSet = pastSet.copyWith(checked: false);
    }

    /// Don't add any previous set for [ExerciseType.Duration]
    /// Duration is captured in realtime from a fresh instance
    seededSets = withReps(type: exercise.type) ? [newSet] : [];

    final logToAdd = _createExerciseLog(exercise, pastSets: seededSets);

    _exerciseLogs = [..._exerciseLogs, logToAdd];
  }

  void reOrderExerciseLogs({required List<ExerciseLogDto> reOrderedList}) {
    _exerciseLogs = reOrderedList;
  }

  ExerciseLogDto? whereExerciseLog({required String exerciseId}) {
    // Search by exercise ID (not exercise log ID) since callers pass exercise.id
    return _exerciseLogs.firstWhereOrNull(
        (exerciseLog) => exerciseLog.exercise.id == exerciseId);
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
    if (newExercise.type == ExerciseType.none) {
      throw const FormatException(
          'Exercise type must be selected before adding to the log');
    }
    final oldExerciseLogIndex =
        _indexWhereExerciseLog(exerciseLogId: oldExerciseId);
    final oldExerciseLog = _whereExerciseLog(exerciseLogId: oldExerciseId);
    if (oldExerciseLogIndex == -1 || oldExerciseLog == null) {
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
        sets: withReps(type: newExercise.type) ? [newSet] : [],
        wipeSessionExerciseFields: true,
        wipeTemplateExerciseFields: true);

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

    // Creating a new list by copying the original list
    List<ExerciseLogDto> newExerciseLogs = _copyExerciseLogs();

    final exerciseLog = newExerciseLogs[exerciseLogIndex];
    newExerciseLogs[exerciseLogIndex] = exerciseLog.copyWith(notes: value);

    // Assign the new list to maintain immutability
    _exerciseLogs = newExerciseLogs;
  }

  void updateExerciseLogAlternatives({
    required String exerciseLogId,
    required List<ExerciseDto> alternatives,
  }) {
    final exerciseLogIndex =
        _indexWhereExerciseLog(exerciseLogId: exerciseLogId);

    if (exerciseLogIndex == -1) {
      return;
    }

    // Creating a new list by copying the original list
    List<ExerciseLogDto> newExerciseLogs = _copyExerciseLogs();

    final exerciseLog = newExerciseLogs[exerciseLogIndex];
    newExerciseLogs[exerciseLogIndex] =
        exerciseLog.copyWith(alternatives: alternatives);

    // Assign the new list to maintain immutability
    _exerciseLogs = newExerciseLogs;
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

    // Creating a new list by copying the original list
    List<ExerciseLogDto> newExerciseLogs = _copyExerciseLogs();

    final exerciseLog = newExerciseLogs[exerciseLogIndex];
    final sets = List<SetDto>.from(exerciseLog.sets); // Copy the sets list

    int newIndex = sets.length;

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

    newExerciseLogs[exerciseLogIndex] = exerciseLog.copyWith(sets: sets);

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
    final sets = List<SetDto>.from(exerciseLog.sets); // Copy the sets list

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
    final sets = List<SetDto>.from(exerciseLog.sets); // Copy the sets list

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
      {String notes = "", List<SetDto> pastSets = const [], List<ExerciseDto> alternatives = const []}) {
    return ExerciseLogDto(
        id: exercise.id,
        routineLogId: "",
        superSetId: "",
        exercise: exercise,
        notes: notes,
        sets: pastSets,
        alternatives: alternatives,
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

  ExerciseLogDto? _whereExerciseLog({required String exerciseLogId}) {
    return _exerciseLogs
        .firstWhereOrNull((exerciseLog) => exerciseLog.id == exerciseLogId);
  }

  List<ExerciseLogDto> _copyExerciseLogs() {
    return List<ExerciseLogDto>.from(_exerciseLogs);
  }

  void clear() {
    _exerciseLogs = [];
  }

  /// Updates coach instruction video path for an exercise row (in-memory).
  void updateCoachInstructionVideoPath({
    required String exerciseLogId,
    String? storagePath,
    String? sessionExerciseId,
    String? templateExerciseId,
  }) {
    final exerciseLogIndex =
        _indexWhereExerciseLog(exerciseLogId: exerciseLogId);
    if (exerciseLogIndex == -1) return;

    final newExerciseLogs = _copyExerciseLogs();
    final exerciseLog = newExerciseLogs[exerciseLogIndex];
    if (storagePath == null || storagePath.trim().isEmpty) {
      newExerciseLogs[exerciseLogIndex] = exerciseLog.copyWith(
        clearCoachInstructionVideo: true,
        sessionExerciseId: sessionExerciseId ?? exerciseLog.sessionExerciseId,
        templateExerciseId: templateExerciseId ?? exerciseLog.templateExerciseId,
      );
    } else {
      newExerciseLogs[exerciseLogIndex] = exerciseLog.copyWith(
        coachInstructionVideoPath: storagePath.trim(),
        sessionExerciseId: sessionExerciseId ?? exerciseLog.sessionExerciseId,
        templateExerciseId: templateExerciseId ?? exerciseLog.templateExerciseId,
      );
    }
    _exerciseLogs = newExerciseLogs;
  }
}
