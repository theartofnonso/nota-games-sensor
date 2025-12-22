import 'package:flutter/material.dart';
import 'package:trainware/enums/exercise_type_enums.dart';
import 'package:trainware/widgets/routine/preview/set_headers/single_set_header.dart';

import '../../../dtos/exercise_log_dto.dart';
import '../../../utils/general_utils.dart';
import '../../../utils/navigation_utils.dart';
import 'set_headers/double_set_header.dart';
import 'sets_listview.dart';

class ExerciseLogWidget extends StatefulWidget {
  final ExerciseLogDto exerciseLog;

  const ExerciseLogWidget({super.key, required this.exerciseLog});

  @override
  State<ExerciseLogWidget> createState() => _ExerciseLogWidgetState();
}

class _ExerciseLogWidgetState extends State<ExerciseLogWidget> {
  @override
  Widget build(BuildContext context) {
    final exercise = widget.exerciseLog.exercise;

    final exerciseType = exercise.type;

    return GestureDetector(
      onTap: () => navigateToExerciseHome(
          context: context, exercise: widget.exerciseLog.exercise),
      child: Column(
        spacing: 12,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(widget.exerciseLog.exercise.name,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center),
          if (widget.exerciseLog.notes.isNotEmpty)
            Text(widget.exerciseLog.notes,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium),
          switch (exerciseType) {
            ExerciseType.weights => DoubleSetHeader(
                firstLabel: weightUnit().toUpperCase(), secondLabel: 'REPS'),
            ExerciseType.bodyWeight => SingleSetHeader(label: 'REPS'),
            ExerciseType.duration => SingleSetHeader(label: 'TIME'),
          },
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child:
                SetsListview(type: exerciseType, sets: widget.exerciseLog.sets),
          )
        ],
      ),
    );
  }
}
