import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import 'package:tracker_app/extensions/datetime/datetime_extension.dart';
import 'package:tracker_app/extensions/duration_extension.dart';
import 'package:tracker_app/utils/navigation_utils.dart';
import 'package:tracker_app/widgets/backgrounds/trkr_loading_screen.dart';

import '../../../dtos/exercise_log_dto.dart';
import 'package:tracker_app/controllers/supabase_exercise_and_routine_controller.dart';
import '../../dtos/appsync/routine_template_dto.dart';
import '../../dtos/set_dtos/set_dto.dart';
import '../../dtos/viewmodels/exercise_log_view_model.dart';
import '../../dtos/viewmodels/routine_log_arguments.dart';
import '../../enums/routine_editor_type_enums.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/exercise_logs_utils.dart';
import '../../utils/general_utils.dart';
import '../../utils/routine_utils.dart';
import '../../utils/string_utils.dart';
import '../../widgets/chip_one.dart';
import '../../widgets/empty_states/not_found.dart';
import '../../widgets/icons/custom_icon.dart';
import '../../widgets/monthly_insights/muscle_groups_family_frequency_widget.dart';
import '../../widgets/routine/preview/exercise_log_listview.dart';

class RoutineLogScreen extends StatefulWidget {
  static const routeName = '/routine_log_screen';

  final String id;
  final bool isEditable;

  const RoutineLogScreen({super.key, required this.id, this.isEditable = true});

  @override
  State<RoutineLogScreen> createState() => _RoutineLogScreenState();
}

class _RoutineLogScreenState extends State<RoutineLogScreen> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    if (_loading) return TRKRLoadingScreen(action: _hideLoadingScreen);

    final exerciseAndRoutineController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: true);

    if (exerciseAndRoutineController.errorMessage.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showSnackbar(
            context: context,
            message: exerciseAndRoutineController.errorMessage);
      });
    }

    // Reload log from controller on every build (in case it was updated)
    final log = exerciseAndRoutineController.logWhereId(id: widget.id);

    if (log == null) return const NotFound();

    // We only want to see all logged exercises and sets
    final completedExerciseLogs =
        loggedExercises(exerciseLogs: log.exerciseLogs);

    final updatedLog = log.copyWith(exerciseLogs: completedExerciseLogs);

    final numberOfCompletedSets =
        completedExerciseLogs.expand((exerciseLog) => exerciseLog.sets);

    final muscleGroupFamilyFrequencies =
        muscleGroupFrequency(exerciseLogs: completedExerciseLogs);

    final pbs = updatedLog.exerciseLogs.map((exerciseLog) {
      final pastExerciseLogs =
          exerciseAndRoutineController.whereExerciseLogsBefore(
              exercise: exerciseLog.exercise, date: exerciseLog.createdAt);

      return calculatePBs(
          pastExerciseLogs: loggedExercises(exerciseLogs: pastExerciseLogs),
          exerciseType: exerciseLog.exercise.type,
          exerciseLog: exerciseLog);
    }).expand((pbs) => pbs);

    final logs = exerciseAndRoutineController
        .whereLogsWithTemplateId(templateId: updatedLog.templateId)
        .map((log) => routineWithLoggedExercises(log: log))
        .toList();

    logs.map((log) => log.volume).toList();

    return Scaffold(
        appBar: AppBar(
            backgroundColor: appBarBackgroundColor(context: context),
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const FaIcon(FontAwesomeIcons.squareXmark, size: 28),
              onPressed: context.pop,
            ),
            title: Text(updatedLog.name)),
        floatingActionButton: widget.isEditable
            ? FloatingActionButton(
                heroTag: "routine_log_screen",
                onPressed: _showBottomSheet,
                backgroundColor: themeGradient(context: context).colors.first,
                elevation: 8.0,
                child: const FaIcon(FontAwesomeIcons.penToSquare))
            : null,
        body: Container(
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: themeGradient(context: context),
          ),
          child: SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              child: Column(
                spacing: 20,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Column(
                        spacing: 12,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ChipOne(
                              label: updatedLog.endTime.formattedDayMonthTime(),
                              child: CustomIcon(FontAwesomeIcons.calendarDay,
                                  color: Colors.deepOrange)),
                          Text(
                            updatedLog.notes.isNotEmpty
                                ? "${updatedLog.notes}."
                                : "No notes",
                            style: TextStyle(
                                fontSize: 14,
                                color:
                                    isDarkMode ? Colors.white70 : Colors.black,
                                height: 1.8,
                                fontWeight: FontWeight.w400),
                          )
                        ]),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      spacing: 10,
                      children: [
                        _StatisticWidget(
                          title: "${completedExerciseLogs.length}",
                          subtitle: "Exercises",
                          icon: FontAwesomeIcons.personWalking,
                          information: _StatisticsInformation(
                              title: "Exercises",
                              description:
                                  "The total number of different exercises you completed in a workout session."),
                        ),
                        _StatisticWidget(
                          title: "${numberOfCompletedSets.length}",
                          subtitle: "Sets",
                          icon: FontAwesomeIcons.hashtag,
                          information: _StatisticsInformation(
                              title: "Sets",
                              description:
                                  "The number of rounds you performed for each exercise. A “set” consists of a group of repetitions (reps)."),
                        ),
                        _StatisticWidget(
                          title: volumeInKOrM(log.volume),
                          subtitle: "Volume",
                          icon: FontAwesomeIcons.weightHanging,
                          information: _StatisticsInformation(
                              title: "Volume",
                              description:
                                  "The total amount of work performed during a workout, typically calculated as: Volume = Sets × Reps × Weight."),
                        ),
                        _StatisticWidget(
                          title: updatedLog.duration().hmsDigital(),
                          subtitle: "Duration",
                          icon: FontAwesomeIcons.solidClock,
                          information: _StatisticsInformation(
                              title: "Duration",
                              description:
                                  "The total time you spent on your workout session, from start to finish."),
                        ),
                        _StatisticWidget(
                          title: "${pbs.length}",
                          subtitle: "PBs",
                          icon: FontAwesomeIcons.solidStar,
                          information: _StatisticsInformation(
                              title: "Personal Bests",
                              description:
                                  "Your highest achievement in an exercise, like the heaviest weight lifted, most reps performed, or highest training volume."),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Column(
                      spacing: 20,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MuscleGroupSplitChart(
                            title: "Muscle Groups Split",
                            description:
                                "Here's a breakdown of the muscle groups in your ${updatedLog.name} workout session.",
                            muscleGroup: muscleGroupFamilyFrequencies,
                            minimized: false),
                        ExerciseLogListView(
                            exerciseLogs: _exerciseLogsToViewModels(
                                exerciseLogs: completedExerciseLogs)),
                        const SizedBox(
                          height: 60,
                        )
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ));
  }

  void _showBottomSheet() {
    displayBottomSheet(
        context: context,
        child: Column(children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const FaIcon(FontAwesomeIcons.solidPenToSquare, size: 18),
            horizontalTitleGap: 6,
            title: Text("Edit Log"),
            onTap: _editLog,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const FaIcon(FontAwesomeIcons.solidClock, size: 18),
            horizontalTitleGap: 6,
            title: Text("Edit duration"),
            onTap: _editDuration,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const FaIcon(FontAwesomeIcons.download, size: 18),
            horizontalTitleGap: 6,
            title: Text("Save as template"),
            onTap: _createTemplate,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const FaIcon(
              FontAwesomeIcons.trash,
              size: 18,
              color: Colors.red,
            ),
            horizontalTitleGap: 6,
            title: Text("Delete log",
                style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                    fontSize: 16)),
            onTap: _deleteLog,
          ),
        ]));
  }

  void _showLoadingScreen() {
    if (!mounted) return;
    setState(() {
      _loading = true;
    });
  }

  void _hideLoadingScreen() {
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  List<ExerciseLogViewModel> _exerciseLogsToViewModels(
      {required List<ExerciseLogDto> exerciseLogs}) {
    return exerciseLogs
        .map((exerciseLog) => ExerciseLogViewModel(
            exerciseLog: exerciseLog,
            superSet: whereOtherExerciseInSuperSet(
                firstExercise: exerciseLog, exercises: exerciseLogs)))
        .toList();
  }

  void _editLog() async {
    Navigator.of(context).pop();
    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);
    final log = controller.logWhereId(id: widget.id);

    if (log != null) {
      final copyOfLog = log.copyWith();
      final arguments = RoutineLogArguments(
          log: copyOfLog, editorMode: RoutineEditorMode.edit);
      await navigateToRoutineEditorAndReturnLog(
          context: context, arguments: arguments);
      // No need to update state - controller will notify listeners
    }
  }

  void _editDuration() {
    Navigator.of(context).pop();
    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);
    final log = controller.logWhereId(id: widget.id);

    if (log != null) {
      showDatetimeRangePicker(
          context: context,
          initialDateTimeRange:
              DateTimeRange(start: log.startTime, end: log.endTime),
          onChangedDateTimeRange: (DateTimeRange datetimeRange) async {
            Navigator.of(context).pop();
            final updatedLog = log.copyWith(
                startTime: datetimeRange.start, endTime: datetimeRange.end);
            await Provider.of<SupabaseExerciseAndRoutineController>(context,
                    listen: false)
                .updateLog(log: updatedLog);
            // No need to update state - controller will notify listeners
          });
    }
  }

  void _createTemplate() async {
    Navigator.of(context).pop();

    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);
    final log = controller.logWhereId(id: widget.id);
    if (log != null) {
      _showLoadingScreen();

      try {
        final exercises = log.exerciseLogs.map((exerciseLog) {
          final uncheckedSets = exerciseLog.sets
              .map((set) => set.copyWith(checked: false))
              .toList();

          /// [Exercise.duration] exercises do not have sets in templates
          /// This is because we only need to store the duration of the exercise in [RoutineEditorType.log] i.e data is log in realtime
          final sets = withDurationOnly(type: exerciseLog.exercise.type)
              ? <SetDto>[]
              : uncheckedSets;
          return exerciseLog.copyWith(sets: sets);
        }).toList();
        final templateToCreate = RoutineTemplateDto(
            name: log.name, notes: log.notes, exerciseTemplates: exercises);

        final createdTemplate =
            await Provider.of<SupabaseExerciseAndRoutineController>(context,
                    listen: false)
                .saveTemplate(templateDto: templateToCreate);
        if (mounted) {
          if (createdTemplate != null) {
            navigateToRoutineTemplatePreview(
                context: context, template: createdTemplate);
          }
        }
      } catch (_) {
        if (mounted) {
          showSnackbar(
              context: context,
              message: "Oops, we are unable to create template");
        }
      } finally {
        _hideLoadingScreen();
      }
    }
  }

  void _doDeleteLog() async {
    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);
    final log = controller.logWhereId(id: widget.id);

    if (log != null) {
      try {
        await controller.removeLog(log: log);
        if (mounted) {
          context.pop();
        }
      } catch (_) {
        if (mounted) {
          showSnackbar(
              context: context,
              message: "Oops, we are unable to delete this log");
        }
      } finally {
        _hideLoadingScreen();
      }
    }
  }

  void _deleteLog() {
    Navigator.of(context).pop(); // Close the previous BottomSheet
    showBottomSheetWithMultiActions(
        context: context,
        title: "Delete log?",
        description: "Are you sure you want to delete this log?",
        leftAction: Navigator.of(context).pop,
        rightAction: () {
          Navigator.of(context).pop(); // Close current BottomSheet
          _showLoadingScreen();
          _doDeleteLog();
        },
        leftActionLabel: 'Cancel',
        rightActionLabel: 'Delete',
        isRightActionDestructive: true);
  }
}

class _StatisticsInformation {
  final String title;
  final String description;

  _StatisticsInformation({required this.title, required this.description});
}

class _StatisticWidget extends StatelessWidget {
  final IconData? icon;
  final String title;
  final String subtitle;
  final _StatisticsInformation information;

  const _StatisticWidget(
      {this.icon,
      required this.title,
      required this.subtitle,
      required this.information});

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    final leading = FaIcon(icon, size: 14);

    return GestureDetector(
      onTap: () => showBottomSheetWithNoAction(
          context: context,
          title: information.title,
          description: information.description),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.black12 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                leading,
                const SizedBox(
                  width: 6,
                ),
                Text(subtitle.toUpperCase(),
                    style: Theme.of(context).textTheme.bodySmall)
              ],
            ),
            const SizedBox(
              height: 6,
            ),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}
