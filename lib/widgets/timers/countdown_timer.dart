import 'dart:async';
import 'package:flutter/material.dart';
import 'package:trainware/extensions/duration_extension.dart';

class CountdownTimer extends StatefulWidget {
  /// Total duration to count down from.
  final Duration duration;

  /// If true, display time in a digital format (e.g. 01:23:45),
  /// otherwise use analog format (defined in your extension).
  final bool digital;

  /// Callback each second with the remaining Duration.
  final void Function(Duration duration)? onChangedDuration;

  /// Forces text color to white if true.
  final bool forceLightMode;

  const CountdownTimer({
    super.key,
    required this.duration,
    this.digital = false,
    this.onChangedDuration,
    this.forceLightMode = false,
  });

  @override
  State<CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<CountdownTimer> {
  late Timer _timer;
  late Duration _remainingDuration;

  @override
  void initState() {
    super.initState();
    _remainingDuration = widget.duration;

    // Fire a timer every second to decrement the remaining duration
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          final secondsLeft = _remainingDuration.inSeconds;
          if (secondsLeft <= 1) {
            // When it hits zero or below, stop the timer and clamp to zero
            _remainingDuration = Duration.zero;
            _timer.cancel();
          } else {
            // Decrement by one second
            _remainingDuration =
                _remainingDuration - const Duration(seconds: 1);
          }
        });

        // Notify external listeners of the remaining duration
        widget.onChangedDuration?.call(_remainingDuration);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      widget.digital
          ? _remainingDuration.hmsDigital()
          : _remainingDuration.hmsAnalog(),
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: widget.forceLightMode ? Colors.white : null,
          ),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}
