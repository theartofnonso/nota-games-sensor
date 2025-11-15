import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tracker_app/widgets/bottom_sheets/app_bottom_sheet.dart';
import 'package:tracker_app/widgets/timers/datetime_picker.dart';
import 'package:tracker_app/widgets/timers/datetime_range_picker.dart';

import '../colors.dart';
import '../dtos/appsync/exercise_dto.dart';
import '../widgets/buttons/opacity_button_widget.dart';
import '../widgets/timers/time_picker.dart';

void showSnackbar({required BuildContext context, required String message}) {
  Brightness systemBrightness = Theme.of(context).brightness;
  final isDarkMode = systemBrightness == Brightness.dark;

  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      backgroundColor: isDarkMode ? sapphireDark80 : Colors.grey.shade200,
      behavior: SnackBarBehavior.fixed,
      content: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style:
                  Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
            ),
          ),
        ],
      )));
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
              onSelect: onChangedDateTime,
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
  showAppBottomSheet(
      context: context,
      isScrollControlled: false,
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

void showBottomSheetWithMultiActions(
    {required BuildContext context,
    required String title,
    required String description,
    required void Function() leftAction,
    required void Function() rightAction,
    required String leftActionLabel,
    required String rightActionLabel,
    bool isLeftActionDestructive = false,
    bool isRightActionDestructive = true,
    Color? rightActionColor}) {
  showAppBottomSheet(
      context: context,
      isScrollControlled: false,
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
            Row(mainAxisAlignment: MainAxisAlignment.start, children: [
              OpacityButtonWidget(
                  onPressed: leftAction,
                  label: leftActionLabel,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              const SizedBox(width: 10),
              OpacityButtonWidget(
                  onPressed: rightAction,
                  label: rightActionLabel,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  buttonColor: vibrantGreen)
            ])
          ],
        ),
      ));
}

/// Shows a dialog with similar exercises found
/// Returns true if user confirms to proceed, false otherwise
Future<bool> showSimilarExercisesDialog({
  required BuildContext context,
  required String exerciseName,
  required List<ExerciseDto> similarExercises,
}) async {
  final result = await showAppBottomSheet<bool>(
    context: context,
    isScrollControlled: similarExercises.length > 3,
    isDraggable: similarExercises.length > 3,
    isDismissible: false,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              OpacityButtonWidget(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                label: 'Cancel',
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              const SizedBox(width: 10),
              OpacityButtonWidget(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                label: 'Proceed',
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                buttonColor: vibrantGreen,
              ),
            ],
          ),
        ],
      ),
    ),
  );

  return result ?? false;
}
