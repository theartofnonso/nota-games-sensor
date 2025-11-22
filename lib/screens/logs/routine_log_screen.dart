import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import 'package:trainware/extensions/datetime/datetime_extension.dart';
import 'package:trainware/extensions/duration_extension.dart';
import 'package:trainware/utils/navigation_utils.dart';
import 'package:trainware/widgets/backgrounds/trkr_loading_screen.dart';

import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import '../../dtos/appsync/routine_log_dto.dart';
import '../../dtos/appsync/routine_plan_dto.dart';
import '../../dtos/appsync/routine_template_dto.dart';
import '../../dtos/set_dtos/set_dto.dart';
import '../../dtos/viewmodels/routine_log_arguments.dart';
import '../../dtos/viewmodels/routine_plan_arguments.dart';
import '../../enums/routine_editor_type_enums.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/exercise_logs_utils.dart';
import '../../utils/general_utils.dart';
import '../../utils/string_utils.dart';
import '../../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../../widgets/chip_one.dart';
import '../../widgets/icons/custom_icon.dart';
import '../../widgets/monthly_insights/muscle_groups_family_frequency_widget.dart';
import '../../widgets/routine/preview/exercise_log_listview.dart';
import '../../widgets/routine/preview/plan_picker.dart';

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

    // If the log was deleted while this screen is visible, navigate back quietly
    if (log == null) {
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

    // We only want to see all logged exercises and sets
    final completedExerciseLogs =
        loggedExercises(exerciseLogs: log.exerciseLogs);

    final updatedLog = log.copyWith(exerciseLogs: completedExerciseLogs);

    final numberOfCompletedSets =
        completedExerciseLogs.expand((exerciseLog) => exerciseLog.sets);

    final muscleGroupFamilyFrequencies =
        muscleGroupFrequency(exerciseLogs: completedExerciseLogs);

    // PBs removed from project

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
              icon: const FaIcon(FontAwesomeIcons.solidCircleXmark, size: 28),
              onPressed: context.pop,
            ),
            title: Text(updatedLog.name),
            actions: widget.isEditable
                ? [
                    IconButton(
                        onPressed: _showBottomSheet,
                        icon: const FaIcon(FontAwesomeIcons.ellipsisVertical,
                            size: 22))
                  ]
                : null),
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
                          // Removed routine-level notes; rely on per-exercise notes instead
                        ]),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      spacing: 2,
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
                        // PBs card removed
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
                            exerciseLogs: completedExerciseLogs),
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
    showAppBottomSheet(
        context: context,
        isScrollControlled: false,
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const FaIcon(FontAwesomeIcons.solidPenToSquare, size: 18),
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
              title: Text("Save as template into..."),
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
          ]),
        ));
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
      if (mounted) {
        _showBottomSheet();
      }
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
            if (mounted) {
              _showBottomSheet();
            }
          });
    }
  }

  void _createTemplate() async {
    Navigator.of(context).pop();

    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);
    final log = controller.logWhereId(id: widget.id);

    if (log == null) return;

    // Get all plans
    final plans = controller.plans;

    // Show plan picker to select which plan to save template into
    _showPlanPickerForTemplate(log: log, plans: plans.toList());
    // When the plan picker closes without selection, re-open this sheet
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Delay to ensure the plan picker has closed
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted) _showBottomSheet();
        });
      }
    });
  }

  void _showPlanPickerForTemplate(
      {required RoutineLogDto log, required List<RoutinePlanDto> plans}) {
    showAppBottomSheet(
      context: context,
      isScrollControlled: false,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: PlanPicker(
          title: "Save as template into...",
          plans: plans,
          onSelect: (selectedPlan) async {
            Navigator.of(context).pop();
            await _doCreateTemplate(log: log, planId: selectedPlan.id);
            if (mounted) {
              _showBottomSheet();
            }
          },
          onCreatePlan: () async {
            Navigator.of(context).pop(); // Close bottom sheet
            // Navigate to create a new plan
            final emptyPlan = RoutinePlanDto(id: "", name: "", notes: "");
            final arguments = RoutinePlanArguments(plan: emptyPlan);
            final newPlan = await navigateToRoutinePlanEditor(
              context: context,
              arguments: arguments,
            );
            // If plan was created, show picker again with the new plan
            if (newPlan != null && mounted) {
              final controller =
                  Provider.of<SupabaseExerciseAndRoutineController>(context,
                      listen: false);
              _showPlanPickerForTemplate(
                  log: log, plans: controller.plans.toList());
            }
          },
        ),
      ),
    );
  }

  Future<void> _doCreateTemplate(
      {required RoutineLogDto log, required String planId}) async {
    _showLoadingScreen();

    try {
      final exercises = log.exerciseLogs.map((exerciseLog) {
        final uncheckedSets = exerciseLog.sets
            .map((set) => set.copyWith(checked: false))
            .toList();

        /// [Exercise.duration] exercises do not have sets in templates
        final List<SetDto> sets =
            withDurationOnly(type: exerciseLog.exercise.type)
                ? <SetDto>[]
                : uncheckedSets;
        return exerciseLog.copyWith(sets: sets);
      }).toList();

      final templateToCreate = RoutineTemplateDto(
          planId: planId, name: log.name, exerciseTemplates: exercises);

      final createdTemplate =
          await Provider.of<SupabaseExerciseAndRoutineController>(context,
                  listen: false)
              .saveTemplate(templateDto: templateToCreate);

      _hideLoadingScreen();

      if (mounted) {
        if (createdTemplate != null) {
          navigateToRoutineTemplatePreview(
              context: context, template: createdTemplate);
        } else {
          showSnackbar(
              context: context,
              message: "Oops, we are unable to create template");
        }
      }
    } catch (e) {
      _hideLoadingScreen();
      debugPrint('Error creating template: $e');
      if (mounted) {
        showSnackbar(
            context: context,
            message: "Oops, we are unable to create template: $e");
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

  // PBs bottom sheet removed
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => showBottomSheetWithNoAction(
          context: context,
          title: information.title,
          description: information.description),
      child: Container(
        constraints: const BoxConstraints(minWidth: 120),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.black.withValues(alpha: 0.3)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon and label row
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  FaIcon(
                    icon,
                    size: 12,
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.6)
                        : Colors.grey.shade600,
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    subtitle.toUpperCase(),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 10,
                          letterSpacing: 0.5,
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.6)
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Large number - no overflow for duration
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: isDarkMode ? Colors.white : Colors.black87,
                    height: 1.1,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
