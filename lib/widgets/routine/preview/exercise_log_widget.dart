import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:tracker_app/enums/exercise_type_enums.dart';
import 'package:tracker_app/widgets/routine/preview/set_headers/single_set_header.dart';

import '../../../dtos/exercise_log_dto.dart';
import '../../../screens/exercise/history/exercise_home_screen.dart';
import '../../../utils/general_utils.dart';
import 'set_headers/double_set_header.dart';
import 'sets_listview.dart';

class ExerciseLogWidget extends StatefulWidget {
  final ExerciseLogDto exerciseLog;
  final ExerciseLogDto? superSet;

  const ExerciseLogWidget(
      {super.key, required this.exerciseLog, this.superSet});

  @override
  State<ExerciseLogWidget> createState() => _ExerciseLogWidgetState();
}

class _ExerciseLogWidgetState extends State<ExerciseLogWidget> {
  @override
  Widget build(BuildContext context) {
    final otherSuperSet = widget.superSet;

    final exercise = widget.exerciseLog.exercise;

    final exerciseType = exercise.type;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (context) =>
                ExerciseHomeScreen(exercise: widget.exerciseLog.exercise)));
      },
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
          if (otherSuperSet != null)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FaIcon(
                  FontAwesomeIcons.link,
                  size: 10,
                ),
                const SizedBox(width: 4),
                Text(otherSuperSet.exercise.name,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
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
