import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:trainware/extensions/datetime/datetime_extension.dart';
import 'package:trainware/extensions/duration_extension.dart';
import 'package:trainware/strings/datetime_range_picker_strings.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

import '../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../widgets/buttons/opacity_button_widget_two.dart';

/// Validates a session duration and returns an error message if invalid,
/// otherwise null.
String? validateSessionDuration(DateTime startTime, DateTime endTime) {
  if (startTime.millisecondsSinceEpoch == endTime.millisecondsSinceEpoch) {
    return editZeroDurationRestriction;
  }

  if (startTime.isAfter(endTime)) {
    return editStartDateMustBeBeforeEndDate;
  }

  if (endTime.isBefore(startTime)) {
    return editEndDateMustBeAfterStartDate;
  }

  if (endTime.millisecondsSinceEpoch >
      DateTime.now().millisecondsSinceEpoch) {
    return editFutureDateRestriction;
  }

  final difference = endTime.difference(startTime);
  if (difference.inHours > 24) {
    return edit24HourRestriction;
  }

  return null;
}

/// Shows a reusable duration selector bottom sheet used for:
/// - Logging past sessions
/// - Editing existing log duration
///
/// The [onConfirm] callback is called only when the selected duration is valid.
Future<void> showSessionDurationSelectorBottomSheet({
  required BuildContext context,
  required DateTime initialStartTime,
  required DateTime initialEndTime,
  required Future<void> Function(DateTime start, DateTime end) onConfirm,
}) async {
  DateTime startTime = initialStartTime;
  DateTime endTime = initialEndTime;

  await showAppBottomSheet(
    context: context,
    isScrollControlled: true,
    child: StatefulBuilder(
      builder: (BuildContext bottomSheetContext, StateSetter setBottomSheet) {
        final theme = Theme.of(context);
        final vibrant = theme.colors.vibrantAccent;

        final errorMessage = validateSessionDuration(startTime, endTime);
        final duration = endTime.difference(startTime);
        final isValid = errorMessage == null;

        return Padding(
          padding: EdgeInsets.only(
            left: 26,
            right: 26,
            top: 26,
            bottom: 26 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Select Duration",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Set the start and end times for this session",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 24),
              _SessionDurationSelectorRow(
                label: "Start Time",
                dateTime: startTime,
                accentColor: vibrant,
                onTimeChanged: (DateTime newDateTime) {
                  startTime = newDateTime;
                  setBottomSheet(() {});
                },
              ),
              const SizedBox(height: 16),
              _SessionDurationSelectorRow(
                label: "End Time",
                dateTime: endTime,
                accentColor: vibrant,
                onTimeChanged: (DateTime newDateTime) {
                  endTime = newDateTime;
                  setBottomSheet(() {});
                },
              ),
              const SizedBox(height: 16),
              if (errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    errorMessage,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.redAccent,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OpacityButtonWidgetTwo(
                  buttonColor: isValid ? vibrant : Colors.grey,
                  label: isValid
                      ? "Log ${duration.hmsAnalog()} session"
                      : "Log Session",
                  onPressed: isValid
                      ? () async {
                          Navigator.of(context).pop();
                          await onConfirm(startTime, endTime);
                        }
                      : null,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Internal row widget with date label and embedded time picker.
class _SessionDurationSelectorRow extends StatefulWidget {
  final String label;
  final DateTime dateTime;
  final Color accentColor;
  final void Function(DateTime newDateTime) onTimeChanged;

  const _SessionDurationSelectorRow({
    required this.label,
    required this.dateTime,
    required this.accentColor,
    required this.onTimeChanged,
  });

  @override
  State<_SessionDurationSelectorRow> createState() =>
      _SessionDurationSelectorRowState();
}

class _SessionDurationSelectorRowState
    extends State<_SessionDurationSelectorRow> {
  late DateTime _currentDateTime;

  @override
  void initState() {
    super.initState();
    _currentDateTime = widget.dateTime;
  }

  @override
  void didUpdateWidget(_SessionDurationSelectorRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dateTime != oldWidget.dateTime) {
      _currentDateTime = widget.dateTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        "${_currentDateTime.day} ${_currentDateTime.abbreviatedMonth()}",
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${_currentDateTime.hour.toString().padLeft(2, '0')}:${_currentDateTime.minute.toString().padLeft(2, '0')}",
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: widget.accentColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            use24hFormat: true,
            initialDateTime: _currentDateTime,
            itemExtent: 40,
            onDateTimeChanged: (DateTime value) {
              setState(() {
                _currentDateTime = DateTime(
                  _currentDateTime.year,
                  _currentDateTime.month,
                  _currentDateTime.day,
                  value.hour,
                  value.minute,
                );
              });
              widget.onTimeChanged(_currentDateTime);
            },
          ),
        ),
      ],
    );
  }
}


