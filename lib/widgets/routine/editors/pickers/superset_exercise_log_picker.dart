import 'package:flutter/material.dart';


import '../../../../colors.dart';
import '../../../../dtos/exercise_log_dto.dart';
import '../../../buttons/opacity_button_widget_two.dart';
import '../../../empty_states/list_tile_empty_state.dart';

class SuperSetExerciseLogPicker extends StatelessWidget {
  final String title;
  final List<ExerciseLogDto> exercises;
  final void Function(ExerciseLogDto exericseLog) onSelect;
  final void Function() onSelectExercisesInLibrary;

  const SuperSetExerciseLogPicker(
      {super.key,
      required this.title,
      required this.exercises,
      required this.onSelect,
      required this.onSelectExercisesInLibrary});

  @override
  Widget build(BuildContext context) {
    final listTiles = exercises
        .map((exercise) => ListTile(
              onTap: () {
                onSelect(exercise);
              },
              contentPadding: EdgeInsets.zero,
              title: Text(
                exercise.exercise.name,
                style: TextStyle(fontWeight: FontWeight.w400),
              ),
            ))
        .toList();

    return exercises.isNotEmpty
        ? SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [Text(title, style: Theme.of(context).textTheme.titleMedium), ...listTiles],
            ),
          )
        : _EmptyState(onPressed: onSelectExercisesInLibrary);
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onPressed;

  const _EmptyState({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          const Padding(
            padding: EdgeInsets.only(left: 18.0),
            child: ListTileEmptyState(),
          ),
          const SizedBox(height: 12),
          const Padding(
            padding: EdgeInsets.only(left: 18.0),
            child: ListTileEmptyState(),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OpacityButtonWidgetTwo(
                onPressed: onPressed,
                label: "Add more exercises",
                buttonColor: vibrantGreen),
          )
        ],
      ),
    );
  }
}
