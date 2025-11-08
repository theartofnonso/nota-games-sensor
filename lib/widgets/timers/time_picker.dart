import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../buttons/opacity_button_widget_two.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

class TimePicker extends StatefulWidget {
  final Duration? initialDuration;
  final void Function(Duration duration) onDurationChanged;
  final CupertinoTimerPickerMode mode;

  const TimePicker(
      {super.key,
      required this.onDurationChanged, this.initialDuration,
      this.mode = CupertinoTimerPickerMode.ms});

  @override
  State<TimePicker> createState() => _TimerPickerState();
}

class _TimerPickerState extends State<TimePicker> {
  late Duration _duration;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: CupertinoTimerPicker(
            initialTimerDuration: _duration,
            mode: widget.mode,
            // This is called when the user changes the timer's
            // duration.
            onTimerDurationChanged: (Duration newDuration) {
              setState(() => _duration = newDuration);
            },
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OpacityButtonWidgetTwo(
              onPressed: () => widget.onDurationChanged(_duration),
              label: "Select duration",
              buttonColor: Theme.of(context).colors.vibrantAccent,),
        )
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    final previousDuration = widget.initialDuration;
    _duration = previousDuration ?? Duration.zero;
  }
}
