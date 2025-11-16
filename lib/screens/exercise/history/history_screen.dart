import 'package:flutter/material.dart';
import 'package:tracker_app/dtos/exercise_log_dto.dart';

import '../../../widgets/empty_states/no_list_empty_state.dart';
import '../../../widgets/exercise_history/exercise_log_history_widget.dart';

class ExerciseLogHistoryScreen extends StatelessWidget {
  final List<ExerciseLogDto> exerciseLogs;

  const ExerciseLogHistoryScreen({super.key, required this.exerciseLogs});

  @override
  Widget build(BuildContext context) {

    // Sort descending by creation time
    final sorted = List<ExerciseLogDto>.from(exerciseLogs)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Padding(
      padding: const EdgeInsets.only(top: 2, right: 10.0, bottom: 10, left: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          exerciseLogs.isNotEmpty
              ? Expanded(
            child: ListView.separated(
                itemBuilder: (BuildContext context, int index) => ExerciseHistoryLogWidget(exerciseLog: sorted[index]),
                separatorBuilder: (BuildContext context, int index) => const SizedBox(height: 22),
                itemCount: sorted.length),
          )
              : Expanded(
                child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: const NoListEmptyState(message: "It might feel quiet now, but your logged exercises will soon appear here."),
                ),
              ),
        ],
      ),
    );
  }
}