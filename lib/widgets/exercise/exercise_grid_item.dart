import 'package:flutter/material.dart';
import 'package:trainware/dtos/appsync/exercise_dto.dart';

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
    final muscleGroup = exercise.primaryMuscleGroup;

    // Get muscle illustration path
    final illustrationPath = 'muscles_illustration/${muscleGroup.name}.png';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.black12 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Muscle group illustration - smaller and centered so it supports
            // the content without overpowering it.
            Expanded(
              child: Center(
                child: Opacity(
                  opacity: 0.85,
                  child: Image.asset(
                    illustrationPath,
                    height: 64,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback if image not found
                      return Icon(
                        Icons.block,
                        size: 32,
                        color:
                            isDarkMode ? Colors.white24 : Colors.grey.shade300,
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Exercise name
            Text(
              exercise.name,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            // Primary muscle group label
            Text(
              muscleGroup.displayName.toUpperCase(),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: isDarkMode ? Colors.white60 : Colors.grey.shade600,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
