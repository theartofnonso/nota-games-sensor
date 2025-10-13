import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:tracker_app/enums/muscle_group_enums.dart';
import 'package:tracker_app/extensions/muscle_group_extension.dart';
import 'package:tracker_app/utils/string_utils.dart';

import '../../dtos/appsync/exercise_dto.dart';

class ExerciseWidget extends StatelessWidget {
  final ExerciseDto exerciseDto;
  final void Function(ExerciseDto exerciseInLibraryDto)? onSelect;
  final void Function(ExerciseDto exerciseInLibraryDto)? onNavigateToExercise;

  const ExerciseWidget(
      {super.key, required this.exerciseDto, required this.onSelect, required this.onNavigateToExercise});

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    final selectExercise = onSelect;
    final navigateToExercise = onNavigateToExercise;

    final exercise = exerciseDto;

    final secondaryMuscleGroupNames =
        exercise.secondaryMuscleGroups.map((muscleGroup) => muscleGroup.name.toUpperCase()).toList();

    return ListTile(
        onTap: () => selectExercise != null ? selectExercise(exerciseDto) : null,
      horizontalTitleGap: 30,
      titleAlignment: ListTileTitleAlignment.titleHeight,
        leading: SizedBox(
          width: 35,
          height: 35, // Adjust the height as needed
          child: Image.asset(
            'muscles_illustration/${exercise.primaryMuscleGroup.illustration()}.png',
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
          ),
        ),
        title: Text(exercise.name, style: Theme.of(context).textTheme.titleMedium),
        subtitle: exercise.primaryMuscleGroup == MuscleGroup.fullBody
            ? Text("Fullbody".toUpperCase(),
                style: TextStyle(color: Colors.deepOrangeAccent, fontWeight: FontWeight.w600, fontSize: 12))
            : RichText(
                text: TextSpan(
                    text: exercise.primaryMuscleGroup.name.toUpperCase(),
                    style: TextStyle(
                        color: Colors.deepOrangeAccent, fontWeight: FontWeight.w600, fontSize: 12, height: 1.5),
                    children: [
                    if (exercise.secondaryMuscleGroups.isNotEmpty)
                      [exercise.primaryMuscleGroup, ...exercise.secondaryMuscleGroups].length == 2
                          ? const TextSpan(text: " & ")
                          : const TextSpan(text: " | "),
                    TextSpan(
                        text: listWithAnd(strings: secondaryMuscleGroupNames),
                        style: TextStyle(
                            color: Colors.orange.withValues(alpha: 0.6), fontWeight: FontWeight.w500, fontSize: 11)),
                  ])),
        trailing: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => navigateToExercise != null ? navigateToExercise(exerciseDto) : null,
          child: FaIcon(
            FontAwesomeIcons.chevronRight,
            size: 12,
            color: isDarkMode ? Colors.white70 : Colors.grey.shade400,
          ),
        ));
  }
}
