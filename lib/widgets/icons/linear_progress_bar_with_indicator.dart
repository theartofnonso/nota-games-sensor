
import 'package:flutter/material.dart';

/// A horizontal progress bar that displays an [icon] sliding along the track
/// proportionally to the current [progress] value.
///
/// * `progress` must be between 0.0 and 1.0.
/// * Animation between progress updates is handled automatically via
///   [AnimatedContainer] & [AnimatedPositioned]; control duration with
///   [animationDuration].
class IconProgressBar extends StatelessWidget {
  /// Current progress, from 0.0 (empty) to 1.0 (full).
  final double progress;

  /// Height of the progress track.
  final double height;

  /// Color of the unfilled portion of the track.
  final Color backgroundColor;

  /// Color of the filled portion of the track.
  final Color? fillColor;

  /// Widget displayed as the sliding indicator. (Often an [Icon]).
  final Widget icon;

  /// Width/height of the [icon].
  final double iconSize;

  /// Duration of the slide / fill animation when [progress] changes.
  final Duration animationDuration;

  const IconProgressBar({
    super.key,
    required this.progress,
    required this.icon,
    this.height = 8,
    this.backgroundColor = const Color(0xFFE0E0E0),
    this.fillColor,
    this.iconSize = 24,
    this.animationDuration = const Duration(milliseconds: 800),
  }) : assert(progress >= 0 && progress <= 1, 'progress must be between 0 and 1');

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final iconLeft = (trackWidth - iconSize) * progress;

        return Stack(
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.none,
          children: [
            // Background track
            Container(
              height: height,
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Filled track
            AnimatedContainer(
              duration: animationDuration,
              height: height,
              width: trackWidth * progress,
              decoration: BoxDecoration(
                color: fillColor ?? Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Sliding icon
            AnimatedPositioned(
              duration: animationDuration,
              left: iconLeft,
              top: -(iconSize - height) / 2, // vertically center icon over track
              child: SizedBox(
                width: iconSize,
                height: iconSize,
                child: FittedBox(child: icon),
              ),
            ),
          ],
        );
      },
    );
  }
}
