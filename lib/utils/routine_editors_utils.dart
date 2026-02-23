import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_flavor.dart';
import '../controllers/exercise_log_controller.dart';
import '../dtos/appsync/exercise_dto.dart';
import '../dtos/exercise_log_dto.dart';
import '../enums/exercise_type_enums.dart';
import '../enums/routine_editor_type_enums.dart';
import '../screens/exercise/library/exercise_library_screen.dart';
import '../utils/dialog_utils.dart';
import '../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../widgets/picker.dart';
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
    isDismissible: true,
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
  String? templateId,
}) {
  final timerRunningNotifier = ValueNotifier<bool>(false);
  // Check if exercise type is duration (DR) to prevent closing without confirmation
  final exerciseLogController =
      Provider.of<ExerciseLogController>(context, listen: false);
  final exerciseLog =
      exerciseLogController.whereExerciseLog(exerciseId: exerciseLogId);
  final isDurationExercise =
      exerciseLog?.exercise.type == ExerciseType.duration;

  showAppBottomSheet(
    context: context,
    isDraggable: true,
    isDismissible: true,
    enableDrag: true,
    initialChildSize: 0.9,
    minChildSize: 0.5,
    maxChildSize: 0.95,
    builder: (context, scrollController) {
      final widget = ExerciseLogWidget(
        exerciseLogId: exerciseLogId,
        editorType: editorType,
        showSetCheck: showSetCheck,
        timerRunningNotifier: timerRunningNotifier,
        templateId: templateId,
      );

      // For duration exercises, intercept all close attempts (drag, barrier tap, back).
      // When timer is running, show prompt to stop timer first. Otherwise allow with confirmation.
      if (isDurationExercise) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, dynamic result) async {
            if (didPop) return;

            if (timerRunningNotifier.value) {
              if (context.mounted) {
                showBottomSheetWithSingleAction(
                  context: context,
                  title: 'Timer running',
                  description:
                      'Please stop the timer before closing this exercise.',
                  action: () => Navigator.of(context).pop(),
                  actionLabel: 'OK',
                );
              }
              return;
            }
            final shouldPop = await confirmDiscardChangesBottomSheet(
              context: context,
              title: 'Leave exercise?',
              description: 'Are you sure you want to leave?',
            );
            if (shouldPop && context.mounted) {
              Navigator.of(context).pop();
            }
          },
          child: widget,
        );
      }

      return widget;
    },
  );
}

void showExercisesInLibrary(
    {required BuildContext context,
    required List<ExerciseDto> exercisesToExclude,
    required void Function(List<ExerciseDto> selectedExercises) onSelected,
    ExerciseType? type}) async {
  if (AppConfig.isClient) {
    return;
  }
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
      final normalized = <ExerciseDto>[];
      final shouldAskLogType = type == null;
      for (final ex in selectedExercises) {
        if (!shouldAskLogType) {
          normalized.add(ex);
          continue;
        }
        final picked = await _pickExerciseType(
          context: context,
          exerciseName: ex.name,
        );
        if (picked == null) continue;
        normalized.add(ex.copyWith(type: picked));
      }
      if (normalized.isNotEmpty) {
        onSelected.call(normalized);
      }
    }
  }
}

Future<ExerciseType?> _pickExerciseType(
    {required BuildContext context, required String exerciseName}) {
  final options = ExerciseType.values
      .where((t) => t != ExerciseType.none)
      .toList(growable: false);
  return showAppBottomSheet<ExerciseType>(
    context: context,
    isScrollControlled: false,
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How to log $exerciseName',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 240,
            child: GenericPicker<ExerciseType>(
              items: options,
              labelBuilder: (type) => type.description,
              onItemSelected: (value) => Navigator.of(context).pop(value),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Shared helper to confirm removing an exercise from any editor.
/// The [fromLabel] should be a short descriptor like "workout", "log", or "template".
Future<bool> confirmRemoveExerciseBottomSheet({
  required BuildContext context,
  required String exerciseName,
  required String fromLabel,
}) async {
  bool shouldRemove = false;

  await showAppActionBottomSheet(
    context: context,
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
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OpacityButtonWidgetTwo(
              label: 'Remove',
              buttonColor: Colors.red,
              onPressed: () {
                Navigator.of(context).pop();
                shouldRemove = true;
              },
            ),
          ),
        ],
      ),
    ),
  );

  return shouldRemove;
}
