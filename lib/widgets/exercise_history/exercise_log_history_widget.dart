import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:provider/provider.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/extensions/datetime/datetime_extension.dart';
import 'package:trainware/widgets/empty_states/list_view_empty_state.dart';

import '../../dtos/exercise_log_dto.dart';
import '../../enums/exercise_type_enums.dart';
import '../../utils/general_utils.dart';
import '../routine/preview/set_headers/double_set_header.dart';
import '../routine/preview/set_headers/single_set_header.dart';
import '../routine/preview/sets_listview.dart';

class ExerciseHistoryLogWidget extends StatelessWidget {
  final ExerciseLogDto exerciseLog;

  const ExerciseHistoryLogWidget({
    super.key,
    required this.exerciseLog,
  });

  @override
  Widget build(BuildContext context) {
    final routineLogController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);
    final routineLog =
        routineLogController.logWhereId(id: exerciseLog.routineLogId ?? "");

    if (routineLog == null) {
      return const ListViewEmptyState();
    }

    return Column(
      spacing: 10,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(routineLog.name, style: Theme.of(context).textTheme.titleMedium),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const FaIcon(
            FontAwesomeIcons.calendarDay,
            size: 12,
          ),
          const SizedBox(width: 8),
          Text(exerciseLog.createdAt.formattedDayAndMonthAndYear(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center),
        ]),
        _ExerciseLogWidget(exerciseLog: exerciseLog)
      ],
    );
  }
}

class _ExerciseLogWidget extends StatelessWidget {
  final ExerciseLogDto exerciseLog;

  const _ExerciseLogWidget({required this.exerciseLog});

  @override
  Widget build(BuildContext context) {
    final exerciseType = exerciseLog.exercise.type;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        exerciseLog.notes.isNotEmpty
            ? Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(exerciseLog.notes,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 15)),
              )
            : const SizedBox.shrink(),
        switch (exerciseType) {
          ExerciseType.weights => DoubleSetHeader(
              firstLabel: weightUnit().toUpperCase(), secondLabel: 'REPS'),
          ExerciseType.bodyWeight => const SingleSetHeader(label: 'REPS'),
          ExerciseType.duration => const SingleSetHeader(label: 'TIME')
        },
        const SizedBox(height: 8),
        SetsListview(type: exerciseType, sets: exerciseLog.sets)
      ],
    );
  }
}
