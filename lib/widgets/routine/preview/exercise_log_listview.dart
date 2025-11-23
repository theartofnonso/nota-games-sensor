import 'package:flutter/material.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';

import 'exercise_log_widget.dart';

class ExerciseLogListView extends StatelessWidget {
  final List<ExerciseLogDto> exerciseLogs;

  const ExerciseLogListView({super.key, required this.exerciseLogs});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        itemBuilder: (context, index) {
          final exerciseLog = exerciseLogs[index];
          return ExerciseLogWidget(
            exerciseLog: exerciseLog,
          );
        },
        separatorBuilder: (context, index) {
          return SizedBox(height: 30);
        },
        itemCount: exerciseLogs.length);
  }
}
