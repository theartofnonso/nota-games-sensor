import 'package:flutter/material.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';

import 'exercise_log_widget.dart';

class ExerciseLogListView extends StatelessWidget {
  final List<ExerciseLogDto> exerciseLogs;
  final bool scrollable;
  final ScrollController? controller;

  const ExerciseLogListView({
    super.key,
    required this.exerciseLogs,
    this.scrollable = false,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final list = ListView.separated(
      controller: controller,
      shrinkWrap: !scrollable,
      physics: scrollable
          ? const AlwaysScrollableScrollPhysics()
          : const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final exerciseLog = exerciseLogs[index];
        return ExerciseLogWidget(
          exerciseLog: exerciseLog,
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 30),
      itemCount: exerciseLogs.length,
    );

    return list;
  }
}
