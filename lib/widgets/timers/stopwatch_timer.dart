import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:trainware/extensions/duration_extension.dart';

class StopwatchTimer extends StatefulWidget {
  final DateTime startTime;
  final bool digital;
  final void Function(Duration duration)? onChangedDuration;
  final TextStyle? textStyle;
  final bool forceLightMode;
  final Duration? maxDuration;
  final Duration warningThreshold;
  final Color warningColor;
  final Color exceededColor;

  const StopwatchTimer({
    super.key,
    required this.startTime,
    this.digital = false,
    this.onChangedDuration,
    this.forceLightMode = false,
    this.textStyle,
    this.maxDuration,
    this.warningThreshold = const Duration(seconds: 10),
    this.warningColor = Colors.orange,
    this.exceededColor = Colors.red,
  });

  @override
  State<StopwatchTimer> createState() => _StopwatchTimerState();
}

class _StopwatchTimerState extends State<StopwatchTimer> {
  late Timer _timer;
  Duration _elapsedDuration = Duration.zero;

  @override
  Widget build(BuildContext context) {
    final maxDuration = widget.maxDuration;

    _elapsedDuration = DateTime.now().difference(widget.startTime);

    String elapsedDisplayText = widget.digital
        ? _elapsedDuration.hmsDigital()
        : _elapsedDuration.hmsAnalog();

    final Color? elapsedColor = widget.forceLightMode ? Colors.white : null;
    final TextStyle? elapsedStyle =
        (widget.textStyle ?? Theme.of(context).textTheme.bodyMedium)
            ?.copyWith(color: elapsedColor);

    if (maxDuration != null) {
      final Duration remainingTime = maxDuration - _elapsedDuration;

      // Check if elapsed exceeds max or remaining time is within warning threshold
      if (_elapsedDuration > maxDuration ||
          remainingTime <= widget.warningThreshold) {
        final Duration difference = _elapsedDuration - maxDuration;
        final bool isNegative = difference.isNegative;
        final Duration absoluteDifference = difference.abs();
        final String differenceTimeString = widget.digital
            ? absoluteDifference.hmsDigital()
            : absoluteDifference.hmsAnalog();
        final String differenceDisplayText =
            '${isNegative ? '-' : '+'}$differenceTimeString';

        Color? differenceColor;
        if (_elapsedDuration >= maxDuration) {
          differenceColor = widget.exceededColor;
        } else {
          final Duration remaining = maxDuration - _elapsedDuration;
          if (remaining <= widget.warningThreshold) {
            differenceColor = widget.warningColor;
          }
        }

        final Color? finalDifferenceColor =
            differenceColor ?? (widget.forceLightMode ? Colors.white : null);
        final TextStyle differenceStyle = TextStyle(
          color: finalDifferenceColor,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(elapsedDisplayText, style: elapsedStyle),
            Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: [
                  Text(differenceDisplayText, style: differenceStyle),
                  FaIcon(
                    Icons.info_rounded,
                    size: 12,
                    color: differenceColor,
                  )
                ]),
          ],
        );
      }
    }

    return Text(elapsedDisplayText, style: elapsedStyle);
  }

  @override
  void initState() {
    super.initState();
    _elapsedDuration = DateTime.now().difference(widget.startTime);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final onChangedDuration = widget.onChangedDuration;
      if (onChangedDuration != null) {
        onChangedDuration(_elapsedDuration);
      }
      setState(() {
        _elapsedDuration = DateTime.now().difference(widget.startTime);
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}
