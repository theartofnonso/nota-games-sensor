import 'package:collection/collection.dart';

import '../dtos/appsync/routine_log_dto.dart';
import '../dtos/exercise_log_dto.dart';
import '../enums/template_changes_type_message_enums.dart';
import 'exercise_logs_utils.dart';

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

  /// Check if set values have been changed
  if (isEditor) {
    final updatedSetValuesChangeMessage = hasSetValueChanged(
        exerciseLogs1: exerciseLog1, exerciseLogs2: exerciseLog2);
    unsavedChangesMessage.add(updatedSetValuesChangeMessage);
  }

  return unsavedChangesMessage.whereType<TemplateChange>().toList();
}

Map<String, List<ExerciseLogDto>> groupExerciseLogsByExerciseId(
    {required List<RoutineLogDto> routineLogs}) {
  final exerciseLogs = routineLogs.expand((log) => log.exerciseLogs);
  return groupBy(exerciseLogs, (exerciseLog) => exerciseLog.exercise.id);
}
