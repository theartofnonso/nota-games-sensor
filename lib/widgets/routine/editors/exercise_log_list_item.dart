import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/widgets/list_tile.dart';

class ExerciseLogListItem extends StatelessWidget {
  final ExerciseLogDto exerciseLogDto;
  final ExerciseLogDto? superSet;
  final VoidCallback onTap;
  final VoidCallback onMenuTap;
  final bool showOnlyTotalSets;

  const ExerciseLogListItem({
    super.key,
    required this.exerciseLogDto,
    this.superSet,
    required this.onTap,
    required this.onMenuTap,
    this.showOnlyTotalSets = false,
  });

  @override
  Widget build(BuildContext context) {
    final totalSets = exerciseLogDto.sets.length;
    final completedSets =
        exerciseLogDto.sets.where((set) => set.checked).length;
    final isCompleted = totalSets > 0 && completedSets == totalSets;

    final progressText = showOnlyTotalSets
        ? '$totalSets sets'
        : '$completedSets/$totalSets sets';

    return ThemeListTile(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        onTap: onTap,
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted
                  ? Theme.of(context).colors.vibrantAccent
                  : Colors.white.withOpacity(0.4),
              width: 2,
            ),
            color: isCompleted
                ? Theme.of(context).colors.vibrantAccent.withOpacity(0.15)
                : Colors.transparent,
          ),
          child: Center(
            child: FaIcon(
              isCompleted ? FontAwesomeIcons.check : FontAwesomeIcons.circle,
              size: 18,
              color: isCompleted
                  ? Theme.of(context).colors.vibrantAccent
                  : Colors.white70,
            ),
          ),
        ),
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
        trailing: IconButton(
          icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 16),
          onPressed: onMenuTap,
          color: Colors.white70,
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
        ),
      ),
    );
  }

  Widget _buildSubtitle({
    required BuildContext context,
    required String progressText,
    required bool isCompleted,
  }) {
    final superSetExercise = superSet;

    Widget content;

    if (superSetExercise == null) {
      content = _buildProgressPill(
        context: context,
        progressText: progressText,
        isCompleted: isCompleted,
      );
    } else {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(
                FontAwesomeIcons.link,
                size: 10,
                color: Colors.white.withOpacity(0.7),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  superSetExercise.exercise.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          _buildProgressPill(
            context: context,
            progressText: progressText,
            isCompleted: isCompleted,
          ),
        ],
      );
    }

    // Ensure the subtitle only wraps its intrinsic width (doesn't stretch)
    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1.0,
      child: content,
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
