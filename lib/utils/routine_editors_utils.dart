import 'package:flutter/material.dart';

import '../dtos/appsync/exercise_dto.dart';
import '../dtos/exercise_log_dto.dart';
import '../enums/exercise_type_enums.dart';
import '../enums/routine_editor_type_enums.dart';
import '../screens/exercise/library/exercise_library_screen.dart';
import '../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../widgets/routine/editors/exercise_log_widget.dart';
import '../widgets/routine/editors/pickers/superset_exercise_log_picker.dart';

void showSuperSetExercisePicker(
    {required BuildContext context,
    required ExerciseLogDto firstExerciseLog,
    required List<ExerciseLogDto> otherExerciseLogs,
    required Function(ExerciseLogDto secondExercise) onSelected,
    required Function() selectExercisesInLibrary}) {
  showAppBottomSheet(
    context: context,
    isDraggable: true,
    builder: (context, scrollController) {
      return Padding(
        padding: const EdgeInsets.all(26),
        child: SuperSetExerciseLogPicker(
          title: "Superset ${firstExerciseLog.exercise.name} with . . .",
          exercises: otherExerciseLogs,
          onSelect: onSelected,
          onSelectExercisesInLibrary: selectExercisesInLibrary,
        ),
      );
    },
  );
}

void showExerciseLogEditor({
  required BuildContext context,
  required String exerciseLogId,
  required RoutineEditorMode editorType,
}) {
  showAppBottomSheet(
    context: context,
    isDraggable: true,
    initialChildSize: 0.9,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    builder: (context, scrollController) {
      return ExerciseLogWidget(
        exerciseLogId: exerciseLogId,
        editorType: editorType,
      );
    },
  );
}

void showExercisesInLibrary(
    {required BuildContext context,
    required List<ExerciseDto> exercisesToExclude,
    required void Function(List<ExerciseDto> selectedExercises) onSelected,
    ExerciseType? type}) async {
  final selectedExercises = await Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => ExerciseLibraryScreen(
            excludeExercises: exercisesToExclude,
            type: type,
          ))) as List<ExerciseDto>?;

  if (context.mounted) {
    if (selectedExercises != null && selectedExercises.isNotEmpty) {
      onSelected.call(selectedExercises);
    }
  }
}
