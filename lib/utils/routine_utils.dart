import 'package:collection/collection.dart';
import 'package:trainware/enums/muscle_group_enums.dart';

import '../dtos/appsync/routine_log_dto.dart';
import '../dtos/exercise_log_dto.dart';
import '../dtos/viewmodels/exercise_log_view_model.dart';
import '../enums/template_changes_type_message_enums.dart';
import 'exercise_logs_utils.dart';

List<ExerciseLogDto> whereOtherExerciseLogsExcept(
    {required ExerciseLogDto exerciseLog,
    required List<ExerciseLogDto> others}) {
  return others
      .where((procedure) =>
          procedure.id != exerciseLog.id && procedure.superSetId.isEmpty)
      .toList();
}

List<TemplateChange> checkForChanges(
    {required List<ExerciseLogDto> exerciseLog1,
    required List<ExerciseLogDto> exerciseLog2,
    bool isEditor = true}) {
  List<TemplateChange?> unsavedChangesMessage = [];

  /// Check if [ExerciseLogDto] have been added or removed
  final differentExercisesLengthMessage = hasDifferentExerciseLogsLength(
      exerciseLogs1: exerciseLog1, exerciseLogs2: exerciseLog2);
  unsavedChangesMessage.add(differentExercisesLengthMessage);

  /// Check if [ExerciseLogDto] has been re-ordered
  final differentExercisesOrderMessage = hasReOrderedExercises(
      exerciseLogs1: exerciseLog1, exerciseLogs2: exerciseLog2);
  unsavedChangesMessage.add(differentExercisesOrderMessage);

  /// Check if [SetDto]'s have been added or removed
  final differentSetsLengthMessage = hasDifferentSetsLength(
      exerciseLogs1: exerciseLog1, exerciseLogs2: exerciseLog2);
  unsavedChangesMessage.add(differentSetsLengthMessage);

  /// Check if [ExerciseType] for [Exercise] in [ExerciseLogDto] has been changed
  final differentExerciseTypesChangeMessage = hasExercisesChanged(
      exerciseLogs1: exerciseLog1, exerciseLogs2: exerciseLog2);
  unsavedChangesMessage.add(differentExerciseTypesChangeMessage);

  /// Check if superset in [ExerciseLogDto] has been changed i.e. added or removed
  final differentSuperSetIdsChangeMessage = hasSuperSetIdChanged(
      exerciseLogs1: exerciseLog1, exerciseLogs2: exerciseLog2);
  unsavedChangesMessage.add(differentSuperSetIdsChangeMessage);

  /// Check if set values have been changed
  if (isEditor) {
    final updatedSetValuesChangeMessage = hasSetValueChanged(
        exerciseLogs1: exerciseLog1, exerciseLogs2: exerciseLog2);
    unsavedChangesMessage.add(updatedSetValuesChangeMessage);
  }

  return unsavedChangesMessage.whereType<TemplateChange>().toList();
}

ExerciseLogDto? whereOtherExerciseInSuperSet(
    {required ExerciseLogDto firstExercise,
    required List<ExerciseLogDto> exercises}) {
  return exercises.firstWhereOrNull((exercise) =>
      exercise.superSetId.isNotEmpty &&
      exercise.superSetId == firstExercise.superSetId &&
      exercise.exercise.id != firstExercise.exercise.id);
}

Map<String, List<ExerciseLogDto>> groupExerciseLogsByExerciseId(
    {required List<RoutineLogDto> routineLogs}) {
  final exerciseLogs = routineLogs.expand((log) => log.exerciseLogs);
  return groupBy(exerciseLogs, (exerciseLog) => exerciseLog.exercise.id);
}

Map<MuscleGroup, List<ExerciseLogDto>> groupExerciseLogsByMuscleGroup(
    {required List<RoutineLogDto> routineLogs}) {
  final exerciseLogs = routineLogs.expand((log) => log.exerciseLogs);
  return groupBy(
      exerciseLogs, (exerciseLog) => exerciseLog.exercise.primaryMuscleGroup);
}

String superSetId(
    {required ExerciseLogDto firstExerciseLog,
    required ExerciseLogDto secondExerciseLog}) {
  return "superset_id_${firstExerciseLog.exercise.id}_${secondExerciseLog.exercise.id}";
}

List<ExerciseLogViewModel> exerciseLogsToViewModels(
    {required List<ExerciseLogDto> exerciseLogs}) {
  return exerciseLogs.map((exerciseLog) {
    return ExerciseLogViewModel(
        exerciseLog: exerciseLog,
        superSet: whereOtherExerciseInSuperSet(
            firstExercise: exerciseLog, exercises: exerciseLogs));
  }).toList();
}
