import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import '../../dtos/appsync/exercise_dto.dart';
import '../../utils/lottie_exercise_registry.dart';

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
    const banColor = Color.fromRGBO(255, 255, 255, 0.4);

    return ListTile(
        onTap: () =>
            selectExercise != null ? selectExercise(exerciseDto) : null,
        horizontalTitleGap: 30,
        titleAlignment: ListTileTitleAlignment.titleHeight,
        leading: SizedBox(
            width: 48,
            height: 48,
            child: exercise.isSystem
                ? FutureBuilder<String?>(
                    future: LottieExerciseRegistry.lottieFor(exercise.id),
                    builder: (context, snapshot) {
                      final asset = snapshot.data;
                      if (asset != null) {
                        return Lottie.asset(
                          asset,
                          fit: BoxFit.contain,
                          repeat: true,
                        );
                      }
                      return FaIcon(
                        FontAwesomeIcons.ban,
                        size: 28,
                        color: banColor,
                      );
                    },
                  )
                : FaIcon(
                    FontAwesomeIcons.ban,
                    size: 28,
                    color: banColor,
                  )),
        title:
            Text(exercise.name, style: Theme.of(context).textTheme.titleMedium),
        subtitle: const SizedBox.shrink(),
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
