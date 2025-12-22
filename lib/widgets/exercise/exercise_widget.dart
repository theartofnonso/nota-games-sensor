import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';

import 'package:trainware/utils/lottie_exercise_registry.dart';

import '../../dtos/appsync/exercise_dto.dart';

class ExerciseWidget extends StatelessWidget {
  final ExerciseDto exerciseDto;
  final void Function(ExerciseDto exerciseInLibraryDto)? onSelect;
  final void Function(ExerciseDto exerciseInLibraryDto)? onNavigateToExercise;

  const ExerciseWidget(
      {super.key,
      required this.exerciseDto,
      required this.onSelect,
      required this.onNavigateToExercise});

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    final selectExercise = onSelect;
    final navigateToExercise = onNavigateToExercise;

    final exercise = exerciseDto;

    return ListTile(
        onTap: () =>
            selectExercise != null ? selectExercise(exerciseDto) : null,
        horizontalTitleGap: 30,
        titleAlignment: ListTileTitleAlignment.titleHeight,
        leading: SizedBox(
            width: 48,
            height: 48,
            child: FutureBuilder<String?>(
              future: LottieExerciseRegistry.lottieFor(exercise.name),
              builder: (context, snapshot) {
                final asset = snapshot.data;
                if (asset != null) {
                  return Lottie.asset(
                    asset,
                    fit: BoxFit.contain,
                    repeat: true,
                  );
                }
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return FaIcon(
                  FontAwesomeIcons.ban,
                  size: 28,
                  color: isDark
                      ? Colors.white.withOpacity(0.32)
                      : Colors.black.withOpacity(0.28),
                );
              },
            )),
        title:
            Text(exercise.name, style: Theme.of(context).textTheme.titleMedium),
        subtitle: Text(
          exercise.primaryMuscleGroup.name.toUpperCase(),
          style: TextStyle(
              color: Colors.deepOrangeAccent,
              fontWeight: FontWeight.w600,
              fontSize: 12),
        ),
        trailing: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => navigateToExercise != null
              ? navigateToExercise(exerciseDto)
              : null,
          child: FaIcon(
            FontAwesomeIcons.chevronRight,
            size: 12,
            color: isDarkMode ? Colors.white70 : Colors.grey.shade400,
          ),
        ));
  }
}
