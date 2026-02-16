import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/screens/exercise/history/exercise_chart_screen.dart';
import 'package:trainware/screens/exercise/history/history_screen.dart';

import '../../../dtos/appsync/exercise_dto.dart';
import '../../../utils/dialog_utils.dart';
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
import '../../../utils/name_notes_bottom_sheet.dart';
import '../../../widgets/bottom_sheets/app_bottom_sheet.dart';

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

  bool get _isSystemExercise {
    final exercise = _exercise ?? widget.exercise;
    return exercise.isSystem;
  }

  void _showMenuBottomSheet() {
    if (_isSystemExercise) return;
    showAppBottomSheet(
      context: context,
      isScrollControlled: false,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const FaIcon(
                FontAwesomeIcons.penToSquare,
                size: 18,
              ),
              horizontalTitleGap: 10,
              title: Text("Edit", style: Theme.of(context).textTheme.bodyLarge),
              onTap: () async {
                Navigator.of(context).pop();
                await _showRenameExerciseSheet();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const FaIcon(
                FontAwesomeIcons.trash,
                size: 18,
                color: Colors.red,
              ),
              horizontalTitleGap: 10,
              title: Text("Delete",
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: Colors.red)),
              onTap: () {
                Navigator.of(context).pop();
                showBottomSheetWithSingleAction(
                    context: context,
                    title: "Delete exercise?",
                    description:
                        "Are you sure you want to delete this exercise?",
                    action: () {
                      Navigator.of(context).pop();
                      _deleteExercise(context);
                    },
                    actionLabel: 'Delete',
                    isDestructive: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteExercise(BuildContext context) async {
    if (_isSystemExercise) return;
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
            actions: _isSystemExercise
                ? null
                : [
                    IconButton(
                      onPressed: _showMenuBottomSheet,
                      icon: const FaIcon(
                        FontAwesomeIcons.ellipsisVertical,
                        size: 24,
                      ),
                      tooltip: 'Show menu',
                    )
                  ],
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

  Future<void> _showRenameExerciseSheet() async {
    final exercise = _exercise;
    if (exercise == null) return;

    final details = await showNameNotesBottomSheet(
      context: context,
      title: 'Rename exercise',
      primaryButtonLabel: 'Save',
      initialName: exercise.name,
      initialNotes: exercise.notes,
      emptyNameMessage: 'Please provide a name for this exercise',
    );
    if (details == null) return;

    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);
    final updated = exercise.copyWith(
      name: details.name,
      notes: details.notes,
    );
    await controller.updateExercise(exercise: updated);
    if (mounted) {
      setState(() {
        _exercise = updated;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _exercise = widget.exercise;
  }
}
