import 'package:flutter/material.dart';

/// Pulsing indicator shown while motion batches are being collected.
class RunningIndicator extends StatelessWidget {
  const RunningIndicator({
    super.key,
    required this.controller,
    required this.color,
    this.dimmed = false,
  });

  final AnimationController controller;
  final Color color;

  /// Muted pulse for pre-start / waiting states.
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(controller.value);
        final outerScale = 1 + t * 0.18;
        final innerOpacity = dimmed ? 0.18 + t * 0.22 : 0.45 + t * 0.55;
        final outerAlpha = dimmed ? 0.06 + t * 0.06 : 0.12 + t * 0.1;

        return SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: outerScale,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: outerAlpha),
                  ),
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: innerOpacity),
                  boxShadow: dimmed
                      ? null
                      : [
                          BoxShadow(
                            color: color.withValues(alpha: 0.35 * innerOpacity),
                            blurRadius: 24,
                            spreadRadius: 2,
                          ),
                        ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
