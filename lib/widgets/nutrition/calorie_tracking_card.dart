import 'dart:math';
import 'package:flutter/material.dart';
import 'package:trainware/widgets/cards/frosted_card.dart';

class CalorieTrackingCard extends StatelessWidget {
  final int goalCalories;
  final int remainingCalories;
  final VoidCallback? onTap;

  const CalorieTrackingCard({
    super.key,
    required this.goalCalories,
    required this.remainingCalories,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final consumedCalories =
        (goalCalories - remainingCalories).clamp(0, goalCalories);
    final progress =
        (consumedCalories / goalCalories).clamp(0.0, 1.0).toDouble();

    final card = FrostedCard(
      gradientColors: const [
        Color(0xFFf5c451),
        Color(0xFFf2b744),
        Color(0xFFf1a93a),
      ],
      child: SizedBox(
        height: 170,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'calories left',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.black.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    remainingCalories.toString(),
                    style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                              fontSize: 48,
                            ) ??
                        const TextStyle(
                          color: Colors.black,
                          fontSize: 48,
                          fontWeight: FontWeight.w900,
                          height: 1.0,
                          fontFamily: 'Grift',
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$goalCalories kcal goal',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w500,
                            ) ??
                        TextStyle(
                          color: Colors.black.withValues(alpha: 0.6),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            CalorieGauge(progress: progress),
          ],
        ),
      ),
    );

    if (onTap == null) {
      return card;
    }

    return GestureDetector(
      onTap: onTap,
      child: card,
    );
  }
}

class CalorieGauge extends StatelessWidget {
  final double progress;
  final Color progressColor;
  final Color trackColor;
  final Color knobColor;
  final Color textColor;

  const CalorieGauge({
    super.key,
    required this.progress,
    this.progressColor = Colors.black,
    this.trackColor = const Color(0x1A000000),
    this.knobColor = Colors.black,
    this.textColor = Colors.black,
  });

  @override
  Widget build(BuildContext context) {
    const startAngle = -2.6;
    const sweepAngle = 4.6;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: progress),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, animatedProgress, _) {
        final animatedPercent = (animatedProgress * 100).round();
        return SizedBox(
          width: 140,
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(118, 118),
                painter: _ProgressArcPainter(
                  progress: animatedProgress,
                  trackColor: trackColor,
                  progressColor: progressColor,
                  knobColor: knobColor,
                  strokeWidth: 10,
                  startAngle: startAngle,
                  sweepAngle: sweepAngle,
                ),
              ),
              Text(
                '$animatedPercent%',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: textColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          fontFamily: 'GroutpixFlow',
                        ) ??
                    TextStyle(
                      color: textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'GroutpixFlow',
                    ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProgressArcPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final Color knobColor;
  final double strokeWidth;
  final double startAngle;
  final double sweepAngle;

  const _ProgressArcPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.knobColor,
    required this.strokeWidth,
    required this.startAngle,
    required this.sweepAngle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(rect, startAngle, sweepAngle, false, trackPaint);

    final clamped = progress.clamp(0.0, 1.0);
    final progressSweep = sweepAngle * clamped;
    canvas.drawArc(rect, startAngle, progressSweep, false, progressPaint);

    final knobAngle = startAngle + progressSweep;
    final knobOffset = Offset(
      center.dx + radius * cos(knobAngle),
      center.dy + radius * sin(knobAngle),
    );
    canvas.drawCircle(
      knobOffset,
      strokeWidth * 0.4,
      Paint()..color = knobColor,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressArcPainter oldDelegate) {
    return progress != oldDelegate.progress ||
        trackColor != oldDelegate.trackColor ||
        progressColor != oldDelegate.progressColor ||
        knobColor != oldDelegate.knobColor ||
        strokeWidth != oldDelegate.strokeWidth ||
        startAngle != oldDelegate.startAngle ||
        sweepAngle != oldDelegate.sweepAngle;
  }
}
