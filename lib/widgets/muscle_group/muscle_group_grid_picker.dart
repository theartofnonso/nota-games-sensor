import 'package:flutter/material.dart';
import 'package:tracker_app/enums/muscle_group_enums.dart';
import 'package:tracker_app/extensions/muscle_group_extension.dart';

class MuscleGroupGridPicker extends StatelessWidget {
  final MuscleGroup selectedMuscleGroup;
  final void Function(MuscleGroup muscleGroup) onSelect;

  const MuscleGroupGridPicker({
    super.key,
    required this.selectedMuscleGroup,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final muscleGroups = MuscleGroup.sortedValues;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Select Muscle Group',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 0.85,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: muscleGroups.length,
            itemBuilder: (context, index) {
              final muscleGroup = muscleGroups[index];
              final isSelected = muscleGroup == selectedMuscleGroup;

              return _MuscleGroupGridItem(
                muscleGroup: muscleGroup,
                isSelected: isSelected,
                onTap: () => onSelect(muscleGroup),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _MuscleGroupGridItem extends StatelessWidget {
  final MuscleGroup muscleGroup;
  final bool isSelected;
  final VoidCallback onTap;

  const _MuscleGroupGridItem({
    required this.muscleGroup,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Get muscle illustration path
    final illustrationPath =
        'muscles_illustration/${muscleGroup.illustration()}.png';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDarkMode ? Colors.black26 : Colors.grey.shade200)
              : (isDarkMode ? Colors.black12 : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(12),
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                )
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Muscle group illustration - centered
            Expanded(
              child: Center(
                child: Opacity(
                  opacity: 0.8,
                  child: Image.asset(
                    illustrationPath,
                    height: 60,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback if image not found
                      return Icon(
                        Icons.block,
                        size: 40,
                        color:
                            isDarkMode ? Colors.white38 : Colors.grey.shade400,
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Muscle group name
            Text(
              muscleGroup.displayName,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    fontSize: 11,
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.start,
            ),
          ],
        ),
      ),
    );
  }
}
