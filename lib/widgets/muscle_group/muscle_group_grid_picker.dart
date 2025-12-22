import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:trainware/enums/muscle_group_enums.dart';

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
            Expanded(
              child: Center(
                child: Opacity(
                  opacity: 0.8,
                  child: FaIcon(
                    FontAwesomeIcons.ban,
                    size: 38,
                    color: isDarkMode
                        ? Colors.white38
                        : Colors.grey.shade500.withOpacity(0.8),
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
