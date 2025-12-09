import 'package:flutter/material.dart';

import '../dtos/appsync/exercise_dto.dart';
import '../dtos/exercise_log_dto.dart';
import '../enums/exercise_type_enums.dart';
import '../enums/routine_editor_type_enums.dart';
import '../screens/exercise/library/exercise_library_screen.dart';
import '../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../widgets/buttons/opacity_button_widget_two.dart';
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
  bool showSetCheck = true,
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
        showSetCheck: showSetCheck,
      );
    },
  );
}

void showExercisesInLibrary(
    {required BuildContext context,
    required List<ExerciseDto> exercisesToExclude,
    required void Function(List<ExerciseDto> selectedExercises) onSelected,
    ExerciseType? type}) async {
  final selectedExercises = await showAppBottomSheet<List<ExerciseDto>>(
    context: context,
    isDraggable: true,
    initialChildSize: 0.9,
    minChildSize: 0.6,
    maxChildSize: 0.98,
    child: ExerciseLibraryScreen(
      excludeExercises: exercisesToExclude,
      type: type,
    ),
  );

  if (context.mounted) {
    if (selectedExercises != null && selectedExercises.isNotEmpty) {
      onSelected.call(selectedExercises);
    }
  }
}

/// Shared helper to confirm removing an exercise from any editor.
/// The [fromLabel] should be a short descriptor like "workout", "log", or "template".
Future<bool> confirmRemoveExerciseBottomSheet({
  required BuildContext context,
  required String exerciseName,
  required String fromLabel,
}) async {
  bool shouldRemove = false;

  await showAppBottomSheet(
    context: context,
    isScrollControlled: false,
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Remove exercise?",
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Are you sure you want to remove "$exerciseName" from this $fromLabel?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OpacityButtonWidgetTwo(
                  label: 'Cancel',
                  showArrowRight: false,
                  onPressed: () {
                    Navigator.of(context).pop();
                    shouldRemove = false;
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OpacityButtonWidgetTwo(
                  label: 'Remove',
                  buttonColor: Colors.red,
                  showArrowRight: false,
                  onPressed: () {
                    Navigator.of(context).pop();
                    shouldRemove = true;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  return shouldRemove;
}
