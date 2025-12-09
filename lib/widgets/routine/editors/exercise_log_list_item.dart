import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';
import 'package:trainware/utils/string_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/widgets/list_tile.dart';

class ExerciseLogListItem extends StatelessWidget {
  final ExerciseLogDto exerciseLogDto;
  final VoidCallback onTap;
  final bool showOnlyTotalSets;
  final bool showStatusIcon;

  const ExerciseLogListItem({
    super.key,
    required this.exerciseLogDto,
    required this.onTap,
    this.showOnlyTotalSets = false,
    this.showStatusIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final totalSets = exerciseLogDto.sets.length;
    final completedSets =
        exerciseLogDto.sets.where((set) => set.checked).length;
    // Exercise is completed if all sets are checked (including acknowledgement sets with 0 sets)
    final isCompleted = totalSets > 0 && completedSets == totalSets;

    final progressText = showOnlyTotalSets
        ? '$totalSets ${pluralize(word: "set", count: totalSets)}'
        : '$completedSets/$totalSets ${pluralize(word: "set", count: totalSets)}';

    return ThemeListTile(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        onTap: onTap,
        leading: showStatusIcon
            ? Container(
                width: 33,
                height: 33,
                decoration: BoxDecoration(
                  shape: BoxShape.rectangle,
                  borderRadius: BorderRadius.circular(8),
                  color: isCompleted
                      ? Theme.of(context).colors.vibrantAccent
                      : Colors.white.withValues(alpha: 0.10),
                ),
                child: Center(
                  child: FaIcon(
                    FontAwesomeIcons.check,
                    size: 14,
                    color: isCompleted ? Colors.black : Colors.white54,
                  ),
                ),
              )
            : null,
        title: Text(
          exerciseLogDto.exercise.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
        ),
        subtitle: _buildSubtitle(
          context: context,
          progressText: progressText,
          isCompleted: isCompleted,
        ),
      ),
    );
  }

  Widget _buildSubtitle({
    required BuildContext context,
    required String progressText,
    required bool isCompleted,
  }) {
    // Ensure the subtitle only wraps its intrinsic width (doesn't stretch)
    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1.0,
      child: _buildProgressPill(
        context: context,
        progressText: progressText,
        isCompleted: isCompleted,
      ),
    );
  }

  Widget _buildProgressPill({
    required BuildContext context,
    required String progressText,
    required bool isCompleted,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        progressText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              fontWeight: FontWeight.w600,
              fontSize: 11,
            ),
      ),
    );
  }
}
