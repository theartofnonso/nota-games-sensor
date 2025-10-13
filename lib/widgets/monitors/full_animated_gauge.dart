import 'dart:math' as math;

import 'package:flutter/material.dart';


import '../../utils/general_utils.dart';

/// Full-circle animated gauge.
/// Example:  AnimatedGauge(value: 134, min: 0, max: 200)
class FullAnimatedGauge extends StatefulWidget {
  const FullAnimatedGauge({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.size = 280,
    this.stroke = 16,
    this.rotationPeriod = const Duration(seconds: 6),
    required this.label,
  });

  final int value;
  final double min;
  final double max;

  /// Diameter of the gauge.
  final double size;

  /// Thickness of the coloured stroke.
  final double stroke;

  /// Time it takes for the gradient to make one full revolution.
  final Duration rotationPeriod;

  final String label;

  @override
  State<FullAnimatedGauge> createState() => _FullAnimatedGaugeState();
}

class _FullAnimatedGaugeState extends State<FullAnimatedGauge> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: widget.rotationPeriod,
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SizedBox(
      width: widget.size + widget.stroke,
      height: widget.size + widget.stroke,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) => CustomPaint(
              size: Size.square(widget.size + widget.stroke),
              painter: _GaugePainter(
                value: widget.value,
                min: widget.min,
                max: widget.max,
                stroke: widget.stroke,
                gradientRotation: _ctrl.value,
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "${widget.value}",
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Draws the coloured 360-degree arc + knob.
/// Draws the coloured 360-degree arc + knob.
class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.value,
    required this.min,
    required this.max,
    required this.stroke,
    required this.gradientRotation,
  });

  final int value;
  final double min, max, stroke, gradientRotation;

  // Match semicircle's start angle (left side)
  static const _gradientStartAngle = math.pi;
  // Arc should still start from top (-π/2 is 12 o'clock)
  static const _arcStartAngle = -math.pi / 2;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.width - stroke) / 2;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius + stroke / 2);

    // Background track (same as before)
    final backgroundPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = Colors.grey.withValues(alpha: .15);
    canvas.drawCircle(center, radius, backgroundPaint);

    // Rotating gradient (matches semicircle's gradient position)
    final shader = SweepGradient(
      startAngle: _gradientStartAngle,
      endAngle: _gradientStartAngle + 2 * math.pi,
      transform: GradientRotation(gradientRotation * 2 * math.pi),
      colors: lowToHighIntensityColors(value / max),
    ).createShader(rect);

    final trackPaint = Paint()
      ..shader = shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final percent = ((value - min) / (max - min)).clamp(0, 1);
    final sweep = percent * 2 * math.pi;

    // Draw active arc starting from top
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      _arcStartAngle,
      sweep,
      false,
      trackPaint,
    );

    // ---- knob -------------------------------------------------------------
    final knobAngle = _arcStartAngle + sweep;
    final knobPos = Offset(
      center.dx + radius * math.cos(knobAngle),
      center.dy + radius * math.sin(knobAngle),
    );

    // White knob + thin outline + inner shadow
    canvas.drawCircle(knobPos, stroke * .45, Paint()..color = Colors.white);
    canvas.drawCircle(
      knobPos,
      stroke * .45,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black12,
    );
    canvas.drawCircle(
      knobPos,
      stroke * .3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.black.withValues(alpha: .05),
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.gradientRotation != gradientRotation || old.value != value || old.min != min || old.max != max;
}
