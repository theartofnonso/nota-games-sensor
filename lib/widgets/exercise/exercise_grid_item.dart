import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:trainware/dtos/appsync/exercise_dto.dart';
import 'package:trainware/utils/lottie_exercise_registry.dart';

class ExerciseGridItem extends StatelessWidget {
  final ExerciseDto exercise;
  final VoidCallback onTap;
  /// When true, shows a checkmark overlay for multi-select mode.
  final bool isSelected;

  const ExerciseGridItem({
    super.key,
    required this.exercise,
    required this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const banColor = Color.fromRGBO(255, 255, 255, 0.4);
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.black12 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Center(
                child: Opacity(
                  opacity: 0.9,
                  child: exercise.isSystem
                      ? FutureBuilder<String?>(
                          future: LottieExerciseRegistry.lottieFor(exercise.id),
                          builder: (context, snapshot) {
                            final asset = snapshot.data;
                            if (asset != null) {
                              return Lottie.asset(
                                asset,
                                height: 80,
                                fit: BoxFit.contain,
                                repeat: true,
                              );
                            }
                            return FaIcon(
                              FontAwesomeIcons.ban,
                              size: 38,
                              color: banColor,
                            );
                          },
                        )
                      : FaIcon(
                          FontAwesomeIcons.ban,
                          size: 38,
                          color: banColor,
                        ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              exercise.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
          ],
        ),
      ),
          if (isSelected)
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
