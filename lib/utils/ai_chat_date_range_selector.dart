import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:trainware/extensions/datetime/datetime_extension.dart';
import 'package:trainware/strings/datetime_range_picker_strings.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

import '../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../widgets/buttons/opacity_button_widget_two.dart';

/// Validates a date range for AI chat queries. Returns error message if invalid, null otherwise.
String? validateAiChatDateRange(DateTime dateFrom, DateTime dateTo) {
  final from = DateTime(dateFrom.year, dateFrom.month, dateFrom.day);
  final to = DateTime(dateTo.year, dateTo.month, dateTo.day);

  if (from.isAfter(to)) {
    return editStartDateMustBeBeforeEndDate;
  }

  if (to.isBefore(from)) {
    return editEndDateMustBeAfterStartDate;
  }

  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  if (to.isAfter(todayDate)) {
    return editFutureDateRestriction;
  }

  return null;
}

/// Shows a date range selector bottom sheet for AI chat, matching the edit log duration pattern.
/// Uses date-only pickers (no time). [onConfirm] is called only when the range is valid.
Future<void> showAiChatDateRangeSelectorBottomSheet({
  required BuildContext context,
  required DateTime initialDateFrom,
  required DateTime initialDateTo,
  required Future<void> Function(DateTime dateFrom, DateTime dateTo) onConfirm,
}) async {
  DateTime dateFrom = initialDateFrom;
  DateTime dateTo = initialDateTo;

  await showAppBottomSheet(
    context: context,
    isScrollControlled: true,
    child: StatefulBuilder(
      builder: (BuildContext bottomSheetContext, StateSetter setBottomSheet) {
        final theme = Theme.of(context);
        final vibrant = theme.extension<TRKRColors>()?.vibrantAccent ?? Colors.green;
        final isDark = theme.brightness == Brightness.dark;
        final textColor = isDark ? Colors.white : Colors.black;
        final subtextColor = isDark ? Colors.white70 : Colors.black54;

        final errorMessage = validateAiChatDateRange(dateFrom, dateTo);
        final isValid = errorMessage == null;
        final daysCount = dateTo.difference(dateFrom).inDays + 1;

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
                "Select Date Range",
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Choose the period to query client data",
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: subtextColor,
                ),
              ),
              const SizedBox(height: 24),
              _AiChatDateSelectorRow(
                label: "From Date",
                date: dateFrom,
                accentColor: vibrant,
                onDateChanged: (DateTime newDate) {
                  dateFrom = newDate;
                  setBottomSheet(() {});
                },
              ),
              const SizedBox(height: 16),
              _AiChatDateSelectorRow(
                label: "To Date",
                date: dateTo,
                accentColor: vibrant,
                onDateChanged: (DateTime newDate) {
                  dateTo = newDate;
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
                      ? "Apply ($daysCount day${daysCount == 1 ? '' : 's'})"
                      : "Apply",
                  onPressed: isValid
                      ? () async {
                          Navigator.of(context).pop();
                          await onConfirm(dateFrom, dateTo);
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

/// Internal row widget with date label and embedded date picker (date-only).
class _AiChatDateSelectorRow extends StatefulWidget {
  final String label;
  final DateTime date;
  final Color accentColor;
  final void Function(DateTime newDate) onDateChanged;

  const _AiChatDateSelectorRow({
    required this.label,
    required this.date,
    required this.accentColor,
    required this.onDateChanged,
  });

  @override
  State<_AiChatDateSelectorRow> createState() => _AiChatDateSelectorRowState();
}

class _AiChatDateSelectorRowState extends State<_AiChatDateSelectorRow> {
  late DateTime _currentDate;

  @override
  void initState() {
    super.initState();
    _currentDate = widget.date;
  }

  @override
  void didUpdateWidget(_AiChatDateSelectorRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.date != oldWidget.date) {
      _currentDate = widget.date;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;
    final textColor = isDark ? Colors.white : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: subtextColor,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "${_currentDate.day} ${_currentDate.abbreviatedMonth()} ${_currentDate.year}",
          style: theme.textTheme.titleMedium?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 216,
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.date,
            initialDateTime: _currentDate,
            maximumDate: DateTime.now(),
            itemExtent: 40,
            onDateTimeChanged: (DateTime value) {
              setState(() {
                _currentDate = value;
              });
              widget.onDateChanged(_currentDate);
            },
          ),
        ),
      ],
    );
  }
}
