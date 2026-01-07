import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:trainware/dtos/appsync/exercise_dto.dart';
import 'package:trainware/utils/lottie_exercise_registry.dart';

class ExerciseGridItem extends StatelessWidget {
  final ExerciseDto exercise;
  final VoidCallback onTap;

  const ExerciseGridItem({
    super.key,
    required this.exercise,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    const banColor = Color.fromRGBO(255, 255, 255, 0.4);
    // Try Lottie mapping; otherwise fall back to an icon placeholder
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
    );
  }
}
