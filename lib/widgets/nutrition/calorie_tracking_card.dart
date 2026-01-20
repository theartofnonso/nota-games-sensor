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
    final consumedCalories = goalCalories > 0
        ? (goalCalories - remainingCalories).clamp(0, goalCalories)
        : 0;
    final progress = goalCalories > 0
        ? (consumedCalories / goalCalories).clamp(0.0, 1.0).toDouble()
        : 0.0;

    final card = FrostedCard(
      gradientColors: const [
        Color(0xFFc08a1d),
        Color(0xFFa86f16),
        Color(0xFF8f590f),
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

class NutritionTrackingCarousel extends StatelessWidget {
  final int goalCalories;
  final int remainingCalories;
  final double proteinTarget;
  final double carbsTarget;
  final double fatsTarget;
  final double consumedProtein;
  final double consumedCarbs;
  final double consumedFats;
  final bool hasLogsToday;
  final VoidCallback? onCardTap;

  const NutritionTrackingCarousel({
    super.key,
    required this.goalCalories,
    required this.remainingCalories,
    required this.proteinTarget,
    required this.carbsTarget,
    required this.fatsTarget,
    required this.consumedProtein,
    required this.consumedCarbs,
    required this.consumedFats,
    required this.hasLogsToday,
    this.onCardTap,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.9;

    return SizedBox(
      height: 180,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        children: [
          SizedBox(
            width: cardWidth,
            child: CalorieTrackingCard(
              goalCalories: goalCalories,
              remainingCalories: remainingCalories,
              onTap: onCardTap,
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: cardWidth,
            child: _MacroTrackingCard(
              label: 'protein left',
              target: proteinTarget,
              consumed: consumedProtein,
              hasLogsToday: hasLogsToday,
              gradientColors: const [
                Color(0xFF1f7a41),
                Color(0xFF166534),
                Color(0xFF14532d),
              ],
              progressColor: Colors.black,
              onTap: onCardTap,
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: cardWidth,
            child: _MacroTrackingCard(
              label: 'carbs left',
              target: carbsTarget,
              consumed: consumedCarbs,
              hasLogsToday: hasLogsToday,
              gradientColors: const [
                Color(0xFF1e3a8a),
                Color(0xFF1d4ed8),
                Color(0xFF1e40af),
              ],
              progressColor: Colors.black,
              onTap: onCardTap,
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: cardWidth,
            child: _MacroTrackingCard(
              label: 'fats left',
              target: fatsTarget,
              consumed: consumedFats,
              hasLogsToday: hasLogsToday,
              gradientColors: const [
                Color(0xFF92400e),
                Color(0xFF7c2d12),
                Color(0xFF9a3412),
              ],
              progressColor: Colors.black,
              onTap: onCardTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroTrackingCard extends StatelessWidget {
  final String label;
  final double target;
  final double consumed;
  final bool hasLogsToday;
  final List<Color> gradientColors;
  final Color progressColor;
  final VoidCallback? onTap;

  const _MacroTrackingCard({
    required this.label,
    required this.target,
    required this.consumed,
    required this.hasLogsToday,
    required this.gradientColors,
    required this.progressColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final remaining =
        hasLogsToday && target > 0 ? (target - consumed).clamp(0, target) : 0.0;
    final progress =
        target > 0 ? (consumed / target).clamp(0.0, 1.0).toDouble() : 0.0;

    final card = FrostedCard(
      gradientColors: gradientColors,
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
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.black.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const Spacer(),
                  Text(
                    remaining.toStringAsFixed(0),
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
                    '${target.toStringAsFixed(0)} grams goal',
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
            CalorieGauge(
              progress: progress,
              progressColor: progressColor,
              trackColor: Colors.black.withValues(alpha: 0.12),
              knobColor: progressColor,
              textColor: Colors.black,
            ),
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
