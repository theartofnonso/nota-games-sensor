import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/logger.dart';
import 'package:trainware/utils/lottie_exercise_registry.dart';
import 'package:trainware/screens/exercise/history/exercise_chart_screen.dart';
import 'package:trainware/screens/exercise/history/history_screen.dart';

import '../../../dtos/appsync/exercise_dto.dart';
import '../../../utils/exercise_logs_utils.dart'
    show
        loggedExercises,
        filterExerciseLogsByTimePeriod,
        ExerciseLogTimePeriod,
        heaviestSetVolume,
        heaviestWeight,
        longestDuration,
        mostRepsInSet,
        mostRepsInSession;
import '../../../utils/general_utils.dart';

class ExerciseHomeScreen extends StatefulWidget {
  static const routeName = "/exercise_home_screen";

  final ExerciseDto exercise;

  const ExerciseHomeScreen({super.key, required this.exercise});

  @override
  State<ExerciseHomeScreen> createState() => _ExerciseHomeScreenState();
}

class _ExerciseHomeScreenState extends State<ExerciseHomeScreen> {
  ExerciseDto? _exercise;
  ExerciseLogTimePeriod _timePeriod = ExerciseLogTimePeriod.last30Days;
  static final _logger = getLogger(className: 'ExerciseHomeScreen');

  @override
  void initState() {
    super.initState();
    _exercise = widget.exercise;
    WidgetsBinding.instance.addPostFrameCallback((_) => _logExerciseInfo());
  }

  Future<void> _logExerciseInfo() async {
    final ex = _exercise;
    if (ex == null) return;
    final lottiePath =
        await LottieExerciseRegistry.lottieFor(ex.id);
    _logger.i(
        'View exercise info: name="${ex.name}" id=${ex.id} lottie="${lottiePath ?? "n/a"}"');
  }

  @override
  Widget build(BuildContext context) {
    final exercise = _exercise;

    // If deleted while visible, quietly exit instead of flashing "Not Found"
    if (exercise == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final navigator = Navigator.maybeOf(context);
          if (navigator != null && navigator.canPop()) {
            context.pop();
          }
        }
      });
      return const SizedBox.shrink();
    }

    final exerciseAndRoutineController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);

    final exerciseLogs =
        exerciseAndRoutineController.exerciseLogsByExerciseId[exercise.id] ??
            [];

    final completedExerciseLogs = loggedExercises(exerciseLogs: exerciseLogs);
    final filteredLogs = filterExerciseLogsByTimePeriod(
      exerciseLogs: completedExerciseLogs,
      period: _timePeriod,
    );

    final heaviestSetVolumeRecord =
        heaviestSetVolume(exerciseLogs: filteredLogs);

    final heaviestWeightRecord = heaviestWeight(exerciseLogs: filteredLogs);

    final longestDurationRecord = longestDuration(exerciseLogs: filteredLogs);

    final mostRepsSetRecord = mostRepsInSet(exerciseLogs: filteredLogs);

    final mostRepsSessionRecord = mostRepsInSession(exerciseLogs: filteredLogs);

    return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: appBarBackgroundColor(context: context),
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            toolbarHeight: 80,
            leading: IconButton(
              icon: const FaIcon(FontAwesomeIcons.solidCircleXmark, size: 28),
              onPressed: context.pop,
            ),
            title: Text(exercise.name),
            bottom: TabBar(
              dividerColor: Colors.transparent,
              tabs: [
                Tab(
                    child: Text("Summary",
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600))),
                Tab(
                    child: Text("History",
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(fontWeight: FontWeight.w600))),
              ],
            ),
            actions: null,
          ),
          body: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: themeGradient(context: context),
            ),
            child: SafeArea(
              bottom: false,
              child: TabBarView(
                children: [
                  ExerciseChartScreen(
                    heaviestWeight: heaviestWeightRecord,
                    heaviestSet: heaviestSetVolumeRecord,
                    longestDuration: longestDurationRecord,
                    mostRepsSet: mostRepsSetRecord,
                    mostRepsSession: mostRepsSessionRecord,
                    exercise: exercise,
                    exerciseLogs: filteredLogs,
                    timePeriod: _timePeriod,
                    onTimePeriodChanged: (period) {
                      setState(() => _timePeriod = period);
                    },
                  ),
                  ExerciseLogHistoryScreen(exerciseLogs: filteredLogs),
                ],
              ),
            ),
          ),
        ));
  }

}
