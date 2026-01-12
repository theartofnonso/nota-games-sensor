import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import '../../utils/lottie_exercise_registry.dart';

class LottieEmptyState extends StatelessWidget {
  final String? title;
  final String message;
  final Widget? actionButton;
  final EdgeInsets? padding;

  const LottieEmptyState({
    super.key,
    this.title,
    required this.message,
    this.actionButton,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final defaultPadding =
        padding ?? const EdgeInsets.symmetric(horizontal: 20.0, vertical: 40.0);

    return Padding(
      padding: defaultPadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 160,
            height: 160,
            child: FutureBuilder<String?>(
              future: LottieExerciseRegistry.randomLottie(),
              builder: (context, snapshot) {
                final asset = snapshot.data;
                if (asset != null) {
                  return Lottie.asset(
                    asset,
                    fit: BoxFit.contain,
                    repeat: true,
                  );
                }
                return Icon(
                  FontAwesomeIcons.dumbbell,
                  size: 96,
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.3)
                      : Colors.grey.shade400,
                );
              },
            ),
          ),
          if (title != null) ...[
            const SizedBox(height: 24),
            Text(
              title!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : Colors.black87,
                  ),
            ),
            const SizedBox(height: 12),
          ] else
            const SizedBox(height: 24),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
                ),
          ),
          if (actionButton != null) ...[
            const SizedBox(height: 24),
            actionButton!,
          ],
        ],
      ),
    );
  }
}
