import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:tracker_app/extensions/duration_extension.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

class DurationStopwatchWidget extends StatefulWidget {
  final VoidCallback onLogSet;

  const DurationStopwatchWidget({
    super.key,
    required this.onLogSet,
  });

  @override
  State<DurationStopwatchWidget> createState() =>
      DurationStopwatchWidgetState();
}

class DurationStopwatchWidgetState extends State<DurationStopwatchWidget> {
  Duration _currentDuration = Duration.zero;
  bool _isRunning = false;
  DateTime? _startTime;

  Duration get currentDuration => _currentDuration;

  void _startStopwatch() {
    setState(() {
      _isRunning = true;
      _startTime = DateTime.now().subtract(_currentDuration);
    });
  }

  void _pauseStopwatch() {
    setState(() {
      _isRunning = false;
    });
  }

  void _stopAndLogSet() {
    if (_currentDuration.inSeconds > 0) {
      widget.onLogSet();
    }
  }

  void resetStopwatch() {
    setState(() {
      _currentDuration = Duration.zero;
      _isRunning = false;
      _startTime = null;
    });
  }

  void _updateDuration() {
    if (_isRunning && _startTime != null) {
      setState(() {
        _currentDuration = DateTime.now().difference(_startTime!);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    // Update every 100ms for smooth animation
    Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted && _isRunning) {
        _updateDuration();
      }
      return mounted;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.extension<TRKRColors>()!;
    final hasStarted = _currentDuration.inSeconds > 0 || _isRunning;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: colors.borderLight,
          width: 1,
        ),
      ),
      padding: const EdgeInsets.only(left: 6, top: 6, bottom: 6, right: 6),
      child: Row(
        children: [
          if (hasStarted) ...[
            // Pause button on left (when timer is running or has started)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isRunning ? _pauseStopwatch : _startStopwatch,
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _isRunning
                        ? Colors.orange.withValues(alpha: 0.15)
                        : colors.vibrantAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: FaIcon(
                    _isRunning ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
                    color: _isRunning ? Colors.orange : colors.vibrantAccent,
                    size: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          // Timer display in the middle/right
          Expanded(
            child: Center(
              child: Text(
                _currentDuration.hmsDigital(),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (!hasStarted) ...[
            const SizedBox(width: 12),
            // Start button on right (initial state)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _startStopwatch,
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.vibrantAccent,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.play,
                    color: Colors.black,
                    size: 14,
                  ),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(width: 12),
            // Log set button on right (when timer has started)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _stopAndLogSet,
                borderRadius: BorderRadius.circular(50),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors.vibrantAccent,
                    borderRadius: BorderRadius.circular(50),
                  ),
                  child: FaIcon(
                    FontAwesomeIcons.check,
                    color: Colors.black,
                    size: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
