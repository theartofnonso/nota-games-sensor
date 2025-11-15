import 'dart:math' as math;

import 'package:flutter/material.dart';


import '../../utils/general_utils.dart';

/// A semicircular gauge whose gradient colors rotate slowly with the gauge
/// positioned above the label.
///
/// ```dart
/// const AnimatedGauge(value: 134, min: 0, max: 200)
/// ```
class HalfAnimatedGauge extends StatefulWidget {
  const HalfAnimatedGauge({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.size = 280,
    this.stroke = 16,
    this.rotationPeriod = const Duration(seconds: 6),
     this.label = "", this.labelWidget,
  });

  final int value;
  final double min;
  final double max;

  /// Diameter of the imaginary circle that hosts the 180-degree arc.
  final double size;

  /// Thickness of the colored stroke.
  final double stroke;

  /// Time it takes for the gradient to make one full revolution.
  final Duration rotationPeriod;

  final String label;

  final Widget? labelWidget;

  @override
  State<HalfAnimatedGauge> createState() => _HalfAnimatedGaugeState();
}

class _HalfAnimatedGaugeState extends State<HalfAnimatedGauge> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: widget.rotationPeriod)..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return Stack(
      alignment: Alignment.center,
      children: [
        Center(
          // ⟵ 1. forces the whole gauge to sit in
          child: SizedBox(
            //    the middle of whatever parent it’s in
            width: double.infinity, // ⟵ 2. explicit width instead of Infinity
            height: 100 / 2 + widget.stroke,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, _) {
                return CustomPaint(
                  painter: _GaugePainter(
                    value: widget.value,
                    min: widget.min,
                    max: widget.max,
                    stroke: widget.stroke,
                    gradientRotation: _ctrl.value,
                  ),
                );
              },
            ),
          ),
        ),
        widget.labelWidget ?? Padding(
          padding: const EdgeInsets.only(top: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text("${widget.value}", style: TextStyle(fontSize: 30, height: 1.5, fontWeight: FontWeight.w900)),
              Text(widget.label,
                  style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w400,
                      color: isDarkMode ? Colors.white70 : Colors.grey.shade600)),
            ],
          ),
        )
      ],
    );
  }
}

/// Draws the colored arc + knob.
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

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.width - stroke) / 2;
    final center = Offset(size.width / 2, size.height - stroke / 2);
    final Rect sweepRect = Rect.fromCircle(center: center, radius: radius + stroke / 2);

    // Draw background track (gray arc)
    final backgroundPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..color = Colors.grey.withValues(alpha: 0.15);

    final Path backgroundArc = Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi,
        math.pi,
      );
    canvas.drawPath(backgroundArc, backgroundPaint);

    // Gradient rotates by [gradientRotation] * 360°
    final shader = SweepGradient(
      startAngle: math.pi, // left-most point
      endAngle: math.pi * 3, // completes full circle
      transform: GradientRotation(gradientRotation * 2 * math.pi),
      colors: lowToHighIntensityColors(value / max),
    ).createShader(sweepRect);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke
      ..shader = shader;

    // Calculate the active portion of the arc based on value
    final percent = (value - min) / (max - min);
    final activeAngle = percent.clamp(0, 1) * math.pi;

    // Draw active portion of the arc
    final Path activeArc = Path()
      ..addArc(
        Rect.fromCircle(center: center, radius: radius),
        math.pi,
        activeAngle,
      );
    canvas.drawPath(activeArc, trackPaint);

    // ---- knob position ----------------------------------------------------
    final knobAngle = math.pi + (percent.clamp(0, 1) * math.pi);
    final knobOffset = Offset(
      center.dx + radius * math.cos(knobAngle),
      center.dy + radius * math.sin(knobAngle),
    );

    // Draw shadow under knob
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawCircle(knobOffset, stroke * .45, shadowPaint);

    // Draw white knob
    final knobPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(knobOffset, stroke * .45, knobPaint);

    // Thin outline on knob for contrast
    canvas.drawCircle(
      knobOffset,
      stroke * .45,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.black12
        ..strokeWidth = 2,
    );

    // Add a subtle inner shadow to the knob
    final innerShadowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = Colors.black.withValues(alpha: 0.05);
    canvas.drawCircle(knobOffset, stroke * .3, innerShadowPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) =>
      old.gradientRotation != gradientRotation || old.value != value || old.min != min || old.max != max;
}
