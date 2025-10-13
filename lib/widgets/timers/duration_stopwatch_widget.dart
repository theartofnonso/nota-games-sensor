import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tracker_app/extensions/duration_extension.dart';

import '../../colors.dart';

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
    return Column(
      spacing: 16,
      children: [
        // Timer Display - matching routine log editor style
        Center(
          child: Text(
            _currentDuration.hmsDigital(),
            style: Theme.of(context).textTheme.headlineLarge,
          ),
        ),

        // Control Buttons Row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 12,
          children: [
            // Start/Pause Button
            _ControlButton(
              onPressed: _isRunning ? _pauseStopwatch : _startStopwatch,
              icon: _isRunning ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
              label: _isRunning ? "PAUSE" : "START",
              color: _isRunning ? Colors.orange : vibrantGreen,
            ),

            // Stop Button (only show if timer has started)
            if (_currentDuration.inSeconds > 0)
              _ControlButton(
                onPressed: _stopAndLogSet,
                icon: FontAwesomeIcons.check,
                label: "LOG SET",
                color: vibrantBlue,
              ),
          ],
        ),
      ],
    );
  }
}

// Simple control button widget
class _ControlButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final Color color;

  const _ControlButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: FaIcon(icon, size: 14, color: color),
      label: Text(
        label,
        style: GoogleFonts.ubuntu(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
      style: TextButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}
