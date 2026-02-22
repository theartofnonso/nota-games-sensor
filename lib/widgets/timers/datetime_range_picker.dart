import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:trainware/extensions/datetime/datetime_extension.dart';
import 'package:trainware/extensions/duration_extension.dart';
import 'package:trainware/widgets/information_containers/information_container_lite.dart';

import '../../strings/datetime_range_picker_strings.dart';
import '../buttons/opacity_button_widget.dart';
import '../buttons/opacity_button_widget_two.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

enum DateTimeRangeSelectionMode {
  dateAndTime,
  dateOnly,
}

class DateTimeRangePicker extends StatefulWidget {
  final DateTimeRange? initialDateTimeRange;
  final void Function(DateTimeRange range) onSelectRange;
  final DateTimeRangeSelectionMode selectionMode;
  final String startLabel;
  final String endLabel;
  final String? confirmLabel;

  const DateTimeRangePicker(
      {super.key,
      required this.onSelectRange,
      this.initialDateTimeRange,
      this.selectionMode = DateTimeRangeSelectionMode.dateAndTime,
      this.startLabel = "Start Time",
      this.endLabel = "End Time",
      this.confirmLabel});

  @override
  State<DateTimeRangePicker> createState() => _DateTimeRangePickerState();
}

class _DateTimeRangePickerState extends State<DateTimeRangePicker> {
  late DateTime _startDateTime;
  late DateTime _endDateTime;

  bool _showStartDateTimeRange = false;
  bool _showEndDateTimeRange = false;

  @override
  Widget build(BuildContext context) {
    final errorMessage = _validateDate();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ListTile(
              title: Text(widget.startLabel),
              trailing: SizedBox(
                width: 150,
                child: OpacityButtonWidget(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    onPressed: () {
                      setState(() {
                        _showStartDateTimeRange = !_showStartDateTimeRange;
                        _showEndDateTimeRange = false;
                      });
                    },
                    buttonColor: _showStartDateTimeRange
                        ? Theme.of(context).colors.vibrantAccent
                        : null,
                    label: _formatSelection(_startDateTime)),
              )),
          if (_showStartDateTimeRange)
            SizedBox(
              height: 240,
              child: CupertinoDatePicker(
                  use24hFormat: true,
                  mode: widget.selectionMode == DateTimeRangeSelectionMode.dateOnly
                      ? CupertinoDatePickerMode.date
                      : CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: _startDateTime,
                  onDateTimeChanged: (DateTime value) {
                    setState(() {
                      _startDateTime = value;
                    });
                  }),
            ),
          ListTile(
              title: Text(widget.endLabel),
              trailing: SizedBox(
                width: 150,
                child: OpacityButtonWidget(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    onPressed: () {
                      setState(() {
                        _showStartDateTimeRange = false;
                        _showEndDateTimeRange = !_showEndDateTimeRange;
                      });
                    },
                    buttonColor: _showEndDateTimeRange
                        ? Theme.of(context).colors.vibrantAccent
                        : null,
                    label: _formatSelection(_endDateTime)),
              )),
          if (_showEndDateTimeRange)
            SizedBox(
              height: 240,
              child: CupertinoDatePicker(
                  use24hFormat: true,
                  mode: widget.selectionMode == DateTimeRangeSelectionMode.dateOnly
                      ? CupertinoDatePickerMode.date
                      : CupertinoDatePickerMode.dateAndTime,
                  initialDateTime: _endDateTime,
                  onDateTimeChanged: (DateTime value) {
                    setState(() {
                      _endDateTime = value;
                    });
                  }),
            ),
          SizedBox(
            height: 90,
            child: AnimatedSwitcher(
                duration: const Duration(seconds: 1),
                child: errorMessage != null
                    ? Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: InformationContainerLite(
                            content: errorMessage,
                            color: Colors.orange,
                            useOpacity: true),
                      )
                    : SizedBox(
                        width: double.infinity,
                        child: OpacityButtonWidgetTwo(
                          onPressed: () {
                            final range = DateTimeRange(
                                start: _startDateTime, end: _endDateTime);
                            widget.onSelectRange(range);
                          },
                          label: widget.confirmLabel ??
                              "Log ${_calculateDuration().hmsAnalog()} session",
                          buttonColor: Theme.of(context).colors.vibrantAccent,
                        ),
                      )),
          ),
        ],
      ),
    );
  }

  String? _validateDate() {
    if (_startDateTime.isAfter(_endDateTime)) {
      return editStartDateMustBeBeforeEndDate;
    }

    if (_endDateTime.isBefore(_startDateTime)) {
      return editEndDateMustBeAfterStartDate;
    }

    if (widget.selectionMode == DateTimeRangeSelectionMode.dateAndTime) {
      if (_endDateTime.millisecondsSinceEpoch >
          DateTime.now().millisecondsSinceEpoch) {
        return editFutureDateRestriction;
      }

      Duration difference = _endDateTime.difference(_startDateTime);

      if (difference.inHours > 24) {
        return edit24HourRestriction;
      }
    }

    return null;
  }

  Duration _calculateDuration() {
    return _endDateTime.difference(_startDateTime);
  }

  String _formatSelection(DateTime value) {
    if (widget.selectionMode == DateTimeRangeSelectionMode.dateOnly) {
      return DateFormat('EEE, MMM d').format(value);
    }
    return value.formattedDayMonthTime();
  }

  @override
  void initState() {
    super.initState();
    _startDateTime = widget.initialDateTimeRange?.start ??
        DateTime.now().subtract(const Duration(hours: 1));
    _endDateTime = widget.initialDateTimeRange?.end ?? DateTime.now();
  }
}
