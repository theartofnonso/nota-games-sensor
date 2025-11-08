import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import 'package:tracker_app/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:tracker_app/screens/editors/exercise_editor_screen.dart';
import 'package:tracker_app/screens/exercise/history/exercise_chart_screen.dart';
import 'package:tracker_app/screens/exercise/history/history_screen.dart';
import 'package:tracker_app/shared_prefs.dart';

import '../../../dtos/appsync/exercise_dto.dart';
import '../../../utils/dialog_utils.dart';
import '../../../utils/exercise_logs_utils.dart';
import '../../../utils/general_utils.dart';
import '../../../utils/navigation_utils.dart';
import '../../../widgets/empty_states/not_found.dart';

class ExerciseHomeScreen extends StatefulWidget {
  static const routeName = "/exercise_home_screen";

  final ExerciseDto exercise;

  const ExerciseHomeScreen({super.key, required this.exercise});

  @override
  State<ExerciseHomeScreen> createState() => _ExerciseHomeScreenState();
}

class _ExerciseHomeScreenState extends State<ExerciseHomeScreen> {
  ExerciseDto? _exercise;

  void _deleteExercise(BuildContext context) async {
    context.pop();
    try {
      await Provider.of<SupabaseExerciseAndRoutineController>(context,
              listen: false)
          .removeExercise(exercise: widget.exercise);
      if (context.mounted) {
        context.pop();
      }
    } catch (_) {
      if (context.mounted) {
        showSnackbar(
            context: context,
            message: "Oops, we are unable delete this exercise");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final exercise = _exercise;

    if (exercise == null) return const NotFound();

    final exerciseAndRoutineController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);

    final exerciseLogs =
        exerciseAndRoutineController.exerciseLogsByExerciseId[exercise.id] ??
            [];

    final completedExerciseLogs = loggedExercises(exerciseLogs: exerciseLogs);

    final heaviestSetVolumeRecord =
        heaviestSetVolume(exerciseLogs: completedExerciseLogs);

    final heaviestWeightRecord =
        heaviestWeight(exerciseLogs: completedExerciseLogs);

    final longestDurationRecord =
        longestDuration(exerciseLogs: completedExerciseLogs);

    final mostRepsSetRecord =
        mostRepsInSet(exerciseLogs: completedExerciseLogs);

    final mostRepsSessionRecord =
        mostRepsInSession(exerciseLogs: completedExerciseLogs);

    final menuActions = [
      MenuItemButton(
        onPressed: _navigateToExerciseEditor,
        child: const Text("Edit"),
      ),
      MenuItemButton(
        onPressed: () {
          showBottomSheetWithMultiActions(
              context: context,
              title: "Delete exercise?",
              description: "Are you sure you want to delete this exercise?",
              leftAction: Navigator.of(context).pop,
              rightAction: () => _deleteExercise(context),
              leftActionLabel: 'Cancel',
              rightActionLabel: 'Delete',
              isRightActionDestructive: true);
        },
        child: Text("Delete", style: TextStyle(color: Colors.red)),
      )
    ];

    return DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: appBarBackgroundColor(context: context),
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const FaIcon(FontAwesomeIcons.arrowLeftLong, size: 28),
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
            actions: exercise.owner == SharedPrefs().userId
                ? [
                    MenuAnchor(
                      builder: (BuildContext context, MenuController controller,
                          Widget? child) {
                        return IconButton(
                          onPressed: () {
                            if (controller.isOpen) {
                              controller.close();
                            } else {
                              controller.open();
                            }
                          },
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            size: 24,
                          ),
                          tooltip: 'Show menu',
                        );
                      },
                      menuChildren: menuActions,
                    )
                  ]
                : null,
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
                    exerciseLogs: completedExerciseLogs,
                  ),
                  ExerciseLogHistoryScreen(exerciseLogs: completedExerciseLogs),
                ],
              ),
            ),
          ),
        ));
  }

  void _navigateToExerciseEditor() async {
    final exercise = _exercise;
    if (exercise != null) {
      final updatedExercise = await navigateWithSlideTransition(
          context: context,
          child: ExerciseEditorScreen(exercise: exercise)) as ExerciseDto?;
      if (updatedExercise != null) {
        setState(() {
          _exercise = updatedExercise;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _exercise = widget.exercise;
  }
}
