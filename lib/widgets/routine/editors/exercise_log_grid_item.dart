import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../dtos/exercise_log_dto.dart';
import '../../../enums/routine_editor_type_enums.dart';
import '../../../utils/routine_editors_utils.dart';
import '../../bottom_sheets/app_bottom_sheet.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

class ExerciseLogGridItemWidget extends StatelessWidget {
  final RoutineEditorMode editorType;
  final ExerciseLogDto exerciseLogDto;
  final ExerciseLogDto? superSet;

  /// ExerciseLogDto callbacks
  final VoidCallback onRemoveLog;
  final VoidCallback onReplaceLog;
  final VoidCallback onSuperSet;
  final void Function(String superSetId) onRemoveSuperSet;

  final bool isPastRoutine;

  const ExerciseLogGridItemWidget(
      {super.key,
      required this.editorType,
      required this.exerciseLogDto,
      this.superSet,
      required this.onRemoveLog,
      required this.onReplaceLog,
      required this.onSuperSet,
      required this.onRemoveSuperSet,
      this.isPastRoutine = false});

  @override
  Widget build(BuildContext context) {
    final superSetExerciseDto = superSet;

    // Calculate progress
    final totalSets = exerciseLogDto.sets.length;
    final completedSets =
        exerciseLogDto.sets.where((set) => set.checked).length;
    final progressText = '$completedSets/$totalSets sets';

    return GestureDetector(
      onTap: () {
        showExerciseLogEditor(
          context: context,
          exerciseLogId: exerciseLogDto.exercise.id,
          editorType: editorType,
        );
      },
      onLongPress: () => _showBottomSheet(context: context),
      child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.black12, borderRadius: BorderRadius.circular(12)),
          child: Column(
              spacing: 12,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Muscle group illustration - centered at top
                Expanded(
                  child: Center(
                    child: Opacity(
                      opacity: 0.8,
                      child: Image.asset(
                        'muscles_illustration/${exerciseLogDto.exercise.primaryMuscleGroup.name}.png',
                        height: 60,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Icon(
                            Icons.block,
                            size: 40,
                            color: Colors.white24,
                          );
                        },
                      ),
                    ),
                  ),
                ),
                // Exercise name at bottom (above checkboxes)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(exerciseLogDto.exercise.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    if (superSetExerciseDto != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            FaIcon(
                              FontAwesomeIcons.link,
                              size: 10,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                                child: Text(superSetExerciseDto.exercise.name,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        Theme.of(context).textTheme.bodySmall)),
                          ],
                        ),
                      ),
                  ],
                ),
                // Progress summary
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: completedSets == totalSets && totalSets > 0
                        ? Theme.of(context)
                            .colors
                            .vibrantAccent
                            .withOpacity(0.2)
                        : Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    progressText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: completedSets == totalSets && totalSets > 0
                              ? Theme.of(context).colors.vibrantAccent
                              : Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                  ),
                ),
              ])),
    );
  }

  void _showBottomSheet({required BuildContext context}) {
    showAppBottomSheet(
        context: context,
        isScrollControlled: false,
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: FaIcon(
                FontAwesomeIcons.arrowRightArrowLeft,
                size: 22,
              ),
              horizontalTitleGap: 6,
              title: Text("Replace"),
              onTap: () {
                Navigator.of(context).pop();
                onReplaceLog();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const FaIcon(FontAwesomeIcons.link, size: 18),
              horizontalTitleGap: 6,
              title: Text("Superset"),
              onTap: () {
                Navigator.of(context).pop();
                onSuperSet();
              },
            ),
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const FaIcon(
                  FontAwesomeIcons.trash,
                  size: 18,
                  color: Colors.red,
                ),
                horizontalTitleGap: 6,
                title: Text("Remove",
                    style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                        fontSize: 16)),
                onTap: () {
                  Navigator.of(context).pop();
                  onRemoveLog();
                }),
          ]),
        ));
  }
}
