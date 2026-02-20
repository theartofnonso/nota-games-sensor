import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';
import 'package:trainware/widgets/timers/datetime_picker.dart';
import 'package:trainware/widgets/timers/datetime_range_picker.dart';

import '../colors.dart';
import '../dtos/appsync/exercise_dto.dart';
import '../widgets/buttons/opacity_button_widget_two.dart';
import '../widgets/timers/time_picker.dart';

/// Replaced with bottom sheet - shows a non-dismissible bottom sheet instead of top snackbar
/// All snackbars are now replaced with bottom sheets that require user acknowledgment
void showSnackbar({
  required BuildContext context,
  required String message,
  Color? backgroundColor,
  Duration duration = const Duration(seconds: 3),
}) {
  // Use bottom sheet instead of top snackbar
  showErrorBottomSheet(
    context: context,
    message: message,
    title: 'Notice',
  );
}

void displayTimePicker(
    {required BuildContext context,
    required CupertinoTimerPickerMode mode,
    required Duration initialDuration,
    required void Function(Duration duration) onChangedDuration}) {
  FocusScope.of(context).unfocus();
  showAppBottomSheet(
      context: context,
      isScrollControlled: false,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: SizedBox(
          height: 240,
          child: TimePicker(
              mode: mode,
              initialDuration: initialDuration,
              onDurationChanged: onChangedDuration),
        ),
      ));
}

void showDateTimePicker(
    {required BuildContext context,
    DateTime? initialDateTime,
    required void Function(DateTime datetime) onChangedDateTime,
    bool closeOnSelect = true,
    CupertinoDatePickerMode? mode}) {
  FocusScope.of(context).unfocus();
  showAppBottomSheet(
      context: context,
      isScrollControlled: false,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: SizedBox(
          height: 240,
          child: DatetimePicker(
              onSelect: (value) {
                onChangedDateTime(value);
                if (closeOnSelect) {
                  Navigator.of(context).pop();
                }
              },
              initialDateTime: initialDateTime,
              mode: mode),
        ),
      ));
}

void showDatetimeRangePicker(
    {required BuildContext context,
    DateTimeRange? initialDateTimeRange,
    required void Function(DateTimeRange datetimeRange)
        onChangedDateTimeRange}) {
  FocusScope.of(context).unfocus();
  showAppBottomSheet(
      context: context,
      isScrollControlled: true,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: DateTimeRangePicker(
          initialDateTimeRange: initialDateTimeRange,
          onSelectRange: onChangedDateTimeRange,
        ),
      ));
}

void showBottomSheetWithNoAction(
    {required BuildContext context,
    required String title,
    required String description,
    TextStyle? textStyle}) {
  showAppActionBottomSheet(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.start),
              const SizedBox(
                height: 4,
              ),
              Text(description,
                  style: textStyle ?? Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.start)
            ]),
      ));
}

void showBottomSheetWithSingleAction(
    {required BuildContext context,
    required String title,
    required String description,
    required void Function() action,
    required String actionLabel,
    bool isDestructive = false,
    Color? actionColor,
    bool isDismissible = true}) {
  showAppActionBottomSheet(
      context: context,
      isDismissible: isDismissible,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.start),
            Text(description,
                style: Theme.of(context).textTheme.titleSmall,
                textAlign: TextAlign.start),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OpacityButtonWidgetTwo(
                  onPressed: action,
                  label: actionLabel,
                  buttonColor: isDestructive
                      ? Colors.red
                      : (actionColor ?? vibrantGreen)),
            ),
          ],
        ),
      ));
}

/// Shows a non-dismissible bottom sheet with a message and "Got it" button
/// The sheet can only be dismissed by tapping the "Got it" button
/// Use this to replace SnackBars for error messages
void showErrorBottomSheet({
  required BuildContext context,
  required String message,
  String title = 'Error',
}) {
  showBottomSheetWithSingleAction(
    context: context,
    title: title,
    description: message,
    action: () => Navigator.of(context).pop(),
    actionLabel: 'Got it',
    isDismissible: false,
  );
}

/// Shows a dialog with similar exercises found
/// Returns true if user confirms to proceed, false otherwise
Future<bool> showSimilarExercisesDialog({
  required BuildContext context,
  required String exerciseName,
  required List<ExerciseDto> similarExercises,
}) async {
  bool? result;
  await showAppBottomSheet<bool>(
    context: context,
    isScrollControlled: similarExercises.length > 3,
    isDraggable: similarExercises.length > 3,
    isDismissible: true,
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Similar exercises found',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 8),
          Text(
            'We found ${similarExercises.length} similar ${similarExercises.length == 1 ? 'exercise' : 'exercises'} to "$exerciseName". Do you want to proceed?',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 16),
          if (similarExercises.length <= 10)
            ...similarExercises.map((exercise) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          exercise.name,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        exercise.type.description,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          if (similarExercises.length > 10)
            Text(
              '${similarExercises.length} similar exercises found. Please check your exercise library.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white70,
                  ),
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OpacityButtonWidgetTwo(
              onPressed: () {
                result = true;
                Navigator.of(context).pop(true);
              },
              label: 'Proceed',
              buttonColor: vibrantGreen,
            ),
          ),
        ],
      ),
    ),
  );

  return result ?? false;
}

/// Shows a confirmation dialog when user tries to exit with unsaved changes
/// Returns true if user confirms to discard changes, false otherwise
Future<bool> confirmDiscardChangesBottomSheet({
  required BuildContext context,
  required String title,
  required String description,
}) async {
  bool? result;
  await showAppActionBottomSheet<bool>(
    context: context,
    isDismissible: true, // Allow dismissal for the confirmation dialog itself
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OpacityButtonWidgetTwo(
              onPressed: () {
                result = true;
                Navigator.of(context).pop(true);
              },
              label: 'Leave',
              buttonColor: Colors.red,
            ),
          ),
        ],
      ),
    ),
  );
  return result ?? false;
}
