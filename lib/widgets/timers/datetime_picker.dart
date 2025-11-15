import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../buttons/opacity_button_widget_two.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

class DatetimePicker extends StatefulWidget {
  final DateTime? initialDateTime;
  final void Function(DateTime datetime) onSelect;
  final CupertinoDatePickerMode? mode;

  const DatetimePicker({super.key, this.initialDateTime, required this.onSelect, required this.mode});

  @override
  State<DatetimePicker> createState() => _DatetimePickerState();
}

class _DatetimePickerState extends State<DatetimePicker> {
  DateTime _dateTime = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: CupertinoDatePicker(
              mode: widget.mode ?? CupertinoDatePickerMode.dateAndTime,
              use24hFormat: true,
              onDateTimeChanged: (DateTime value) {
                _dateTime = value;
              }),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OpacityButtonWidgetTwo(
            onPressed: () => widget.onSelect(_dateTime),
            label: "Select date",
            buttonColor: Theme.of(context).colors.vibrantAccent,
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    final previousDateTime = widget.initialDateTime;
    _dateTime = previousDateTime ?? DateTime.now();
  }
}
