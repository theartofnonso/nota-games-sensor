import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tracker_app/utils/general_utils.dart';
import 'package:tracker_app/widgets/timers/datetime_picker.dart';
import 'package:tracker_app/widgets/timers/datetime_range_picker.dart';

import '../colors.dart';
import '../widgets/buttons/opacity_button_widget.dart';
import '../widgets/timers/time_picker.dart';

void showSnackbar({required BuildContext context, required String message}) {
  Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
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

Future<void> displayBottomSheet(
    {required BuildContext context,
    required Widget child,
    Gradient? gradient,
    double? height,
    enabledDrag = true,
    bool isDismissible = true,
    EdgeInsetsGeometry? padding,
    bool isScrollControlled = false}) {
  Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
  final isDarkMode = systemBrightness == Brightness.dark;

  return showModalBottomSheet(
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enabledDrag,
      backgroundColor: Colors.transparent,
      context: context,
      builder: (BuildContext context) => SafeArea(
            minimum: const EdgeInsets.all(10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: height,
                  width: double.infinity,
                  padding: padding ?? const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: isDarkMode ? sapphireDark80 : Colors.grey.shade100,
                      borderRadius: const BorderRadius.all(
                        Radius.circular(20),
                      ),
                      gradient:
                          isDarkMode ? themeGradient(context: context) : null),
                  child: SafeArea(child: child),
                ),
              ],
            ),
          ));
}

void displayTimePicker(
    {required BuildContext context,
    required CupertinoTimerPickerMode mode,
    required Duration initialDuration,
    required void Function(Duration duration) onChangedDuration}) {
  FocusScope.of(context).unfocus();
  displayBottomSheet(
      height: 240,
      context: context,
      child: TimePicker(
          mode: mode,
          initialDuration: initialDuration,
          onDurationChanged: onChangedDuration));
}

void showDateTimePicker(
    {required BuildContext context,
    DateTime? initialDateTime,
    required void Function(DateTime datetime) onChangedDateTime,
    CupertinoDatePickerMode? mode}) {
  FocusScope.of(context).unfocus();
  displayBottomSheet(
      height: 240,
      context: context,
      child: DatetimePicker(
          onSelect: onChangedDateTime,
          initialDateTime: initialDateTime,
          mode: mode));
}

void showDatetimeRangePicker(
    {required BuildContext context,
    DateTimeRange? initialDateTimeRange,
    required void Function(DateTimeRange datetimeRange)
        onChangedDateTimeRange}) {
  FocusScope.of(context).unfocus();
  displayBottomSheet(
      context: context,
      child: DateTimeRangePicker(
        initialDateTimeRange: initialDateTimeRange,
        onSelectRange: onChangedDateTimeRange,
      ),
      isScrollControlled: true);
}

void showBottomSheetWithNoAction(
    {required BuildContext context,
    required String title,
    required String description,
    TextStyle? textStyle}) {
  displayBottomSheet(
      context: context,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.start),
        const SizedBox(
          height: 4,
        ),
        Text(description,
            style: textStyle ?? Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.start)
      ]));
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
  displayBottomSheet(
      context: context,
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
      ));
}
