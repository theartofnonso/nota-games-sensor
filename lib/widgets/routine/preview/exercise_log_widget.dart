import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tracker_app/enums/exercise_type_enums.dart';
import 'package:tracker_app/widgets/routine/preview/set_headers/single_set_header.dart';

import 'package:tracker_app/controllers/supabase_exercise_and_routine_controller.dart';
import '../../../dtos/exercise_log_dto.dart';
import '../../../dtos/set_dtos/set_dto.dart';
import '../../../dtos/set_dtos/weight_and_reps_dto.dart';
import '../../../screens/exercise/history/exercise_home_screen.dart';
import '../../../utils/exercise_logs_utils.dart';
import '../../../utils/general_utils.dart';
import 'set_headers/double_set_header.dart';
import 'sets_listview.dart';

enum StrengthStatus {
  improving(
    description:
        "🌟 You're getting stronger! Handling more volume with less effort shows fantastic adaptation. "
        "Keep that momentum going and consider increasing the challenge next session—just remember to watch your recovery.",
  ),
  declining(
    description:
        "📉 You're feeling a dip in strength. Double-check your sleep, nutrition, and stress levels—"
        "a little extra rest or a small load reduction can help you bounce back stronger!",
  ),
  maintaining(
    description:
        "🔄 Solid consistency! You've maintained performance levels well. "
        "Focus on refining technique and mind-muscle connection to build a perfect foundation for future gains.",
  ),
  potentialOvertraining(
    description:
        "⚠️ Easy there—your body might be on the verge of overtraining. "
        "Consider a short deload or reduce your training volume for a week to fully recover, then ramp back up gradually.",
  ),
  none(
    description: "🤔 We don't have enough data yet to analyze your progress. "
        "Keep logging sessions, and we'll give you tailored feedback as you go!",
  ),
  insufficient(
      description:
          "You've logged only one training. Great job! Log more sessions to track your progress.");

  const StrengthStatus({required this.description});

  final String description;
}

enum WeightAndRPE {
  weight(
      name: "Weight",
      description:
          "Track your heaviest weight lifted to monitor your strength gains and consistent improvement over time."),
  rpe(
      name: "Volume and RPE",
      description:
          "Volume shows how much work you do, while RPE reveals how hard it feels. Progressive volume shows you're handling more work, while lower RPE at the same workload suggests the exercises are feeling easier.");

  const WeightAndRPE({required this.name, required this.description});

  final String name;
  final String description;
}

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
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    final otherSuperSet = widget.superSet;

    final exercise = widget.exerciseLog.exercise;

    final exerciseType = exercise.type;

    final routineLogController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);

    final pastExerciseLogs = routineLogController.whereExerciseLogsBefore(
        exercise: exercise, date: widget.exerciseLog.createdAt);

    final pastSets =
        routineLogController.wherePrevSetsForExercise(exercise: exercise);

    final pbs = calculatePBs(
        pastExerciseLogs: pastExerciseLogs,
        exerciseType: exerciseType,
        exerciseLog: widget.exerciseLog);

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
          // Show progression summary for weight exercises
          if (exerciseType == ExerciseType.weights)
            Container(
              padding: EdgeInsets.symmetric(vertical: 20, horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDarkMode ? Colors.white10 : Colors.black38,
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(5),
              ),
              child: summarizeProgression(
                  values: _weightsForExercise(pastSets: pastSets),
                  context: context,
                  textAlign: TextAlign.center),
            ),
          switch (exerciseType) {
            ExerciseType.weights => DoubleSetHeader(
                firstLabel: weightUnit().toUpperCase(), secondLabel: 'REPS'),
            ExerciseType.bodyWeight => SingleSetHeader(label: 'REPS'),
            ExerciseType.duration => SingleSetHeader(label: 'TIME'),
          },
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: SetsListview(
                type: exerciseType, sets: widget.exerciseLog.sets, pbs: pbs),
          )
        ],
      ),
    );
  }

  List<num> _weightsForExercise({required List<SetDto> pastSets}) {
    return pastSets.reversed
        .map((set) => (set as WeightAndRepsSetDto).weight)
        .toList();
  }
}
