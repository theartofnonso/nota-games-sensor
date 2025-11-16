import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:provider/provider.dart';
import 'package:tracker_app/enums/muscle_group_enums.dart';
import 'package:tracker_app/extensions/datetime/datetime_extension.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

import 'package:tracker_app/controllers/supabase_exercise_and_routine_controller.dart';
import '../../dtos/appsync/routine_plan_dto.dart';
import '../../dtos/appsync/routine_template_dto.dart';
import '../../dtos/viewmodels/routine_log_arguments.dart';
import '../../dtos/viewmodels/routine_template_arguments.dart';
import '../../enums/routine_editor_type_enums.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/exercise_logs_utils.dart';
import '../../utils/general_utils.dart';
import '../../utils/navigation_utils.dart';
import '../../utils/routine_utils.dart';
import '../../utils/string_utils.dart';
import '../../widgets/backgrounds/trkr_loading_screen.dart';
import '../../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../../widgets/calendar/calendar.dart';
import '../../widgets/chip_one.dart';
import '../../dtos/appsync/routine_log_dto.dart';
import '../../widgets/icons/custom_icon.dart';
import '../../widgets/monthly_insights/muscle_groups_family_frequency_widget.dart';
import '../../widgets/routine/preview/exercise_log_listview.dart';
import '../../widgets/routine/preview/plan_picker.dart';
import '../../widgets/routine/preview/routine_log_widget.dart';

enum _OriginalNewValues {
  originalValues(
      name: "Original Values",
      description:
          "Showing values from the last time this template was saved or updated."),
  newValues(
      name: "Recent Values",
      description: "Showing values from your last logged session.");

  const _OriginalNewValues({required this.name, required this.description});

  final String name;
  final String description;
}

class RoutineTemplateScreen extends StatefulWidget {
  static const routeName = '/routine_template_screen';

  final String id;

  const RoutineTemplateScreen({super.key, required this.id});

  @override
  State<RoutineTemplateScreen> createState() => _RoutineTemplateScreenState();
}

class _RoutineTemplateScreenState extends State<RoutineTemplateScreen> {
  bool _loading = false;

  _OriginalNewValues _originalNewValues = _OriginalNewValues.newValues;

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
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

    // Reload template from controller on every build (in case it was updated)
    final template = exerciseAndRoutineController.templateWhere(id: widget.id);

    // If deleted while visible, quietly exit instead of flashing "Not Found"
    if (template == null) {
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

    final plan = exerciseAndRoutineController.planWhere(id: template.planId);

    final muscleGroupFamilyFrequencies =
        muscleGroupFrequency(exerciseLogs: template.exerciseTemplates);

    final allLogsForTemplate = exerciseAndRoutineController
        .whereLogsWithTemplateId(templateId: template.id)
        .map((log) => routineWithLoggedExercises(log: log))
        .toList();

    final muscleGroups = template.exerciseTemplates
        .map((exerciseTemplate) => exerciseTemplate.exercise.primaryMuscleGroup)
        .toSet()
        .map((muscleGroup) => muscleGroup)
        .toList();

    final exerciseTemplates = _originalNewValues == _OriginalNewValues.newValues
        ? () {
            // Find the most recent log for this template
            final templateLogs = exerciseAndRoutineController
                .whereLogsWithTemplateId(templateId: template.id);
            if (templateLogs.isEmpty) {
              // No previous logs for this template - return original template sets
              return template.exerciseTemplates;
            }

            // Sort logs by startTime (most recent first) and get the most recent one
            final sortedLogs = List<RoutineLogDto>.from(templateLogs)
              ..sort((a, b) => b.startTime.compareTo(a.startTime));
            final mostRecentLog = sortedLogs.first;

            // Map each exercise template to its sets from the most recent log
            return template.exerciseTemplates.map((exerciseTemplate) {
              // Find this exercise in the most recent log
              final exerciseLogInMostRecentLog = mostRecentLog.exerciseLogs
                  .where((el) => el.exercise.id == exerciseTemplate.exercise.id)
                  .firstOrNull;

              if (exerciseLogInMostRecentLog != null) {
                // Use sets from the most recent log, unchecked
                final uncheckedSets = exerciseLogInMostRecentLog.sets
                    .map((set) => set.copyWith(checked: false))
                    .toList();
                return exerciseTemplate.copyWith(sets: uncheckedSets);
              }

              // Exercise not found in most recent log - return original template sets
              return exerciseTemplate;
            }).toList();
          }()
        : template.exerciseTemplates;

    return Scaffold(
        floatingActionButton: FloatingActionButton(
            heroTag: UniqueKey,
            backgroundColor: themeGradient(context: context).colors.first,
            elevation: 8.0,
            onPressed: () =>
                _launchRoutineLogEditor(muscleGroups: muscleGroups),
            child: const FaIcon(FontAwesomeIcons.play, size: 24)),
        appBar: AppBar(
          backgroundColor: appBarBackgroundColor(context: context),
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const FaIcon(FontAwesomeIcons.arrowLeftLong, size: 28),
            onPressed: context.pop,
          ),
          actions: [
            IconButton(
                onPressed: () => _showMenuBottomSheet(planDto: plan),
                icon: const FaIcon(Icons.more_vert_rounded))
          ],
        ),
        body: Container(
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: themeGradient(context: context),
          ),
          child: SafeArea(
            bottom: false,
            minimum: const EdgeInsets.only(top: 10.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 20,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Column(
                      spacing: 20,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Text(template.name,
                                style: TextStyle(
                                    fontSize: 20,
                                    height: 1.5,
                                    fontWeight: FontWeight.w900)),
                            if (plan != null)
                              Text(
                                "In ${plan.name}",
                                style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode
                                        ? Colors.white70
                                        : Colors.black,
                                    fontWeight: FontWeight.w400),
                              )
                          ],
                        ),
                        Column(
                          spacing: 12,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ChipOne(
                                label:
                                    "${template.exerciseTemplates.length} ${pluralize(word: "Exercise", count: template.exerciseTemplates.length)}",
                                child: CustomIcon(
                                    FontAwesomeIcons.personWalking,
                                    color: Theme.of(context)
                                        .colors
                                        .vibrantAccent)),
                            Text(
                              template.notes.isNotEmpty
                                  ? "${template.notes}."
                                  : "No notes",
                              style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.black,
                                  height: 1.8,
                                  fontWeight: FontWeight.w400),
                            )
                          ],
                        ),
                        Calendar(
                          onSelectDate: (date) => _showLogsForDate(
                              context, date, allLogsForTemplate),
                          logs: allLogsForTemplate,
                        ),
                        MuscleGroupSplitChart(
                            title: "Muscle Groups Split",
                            description:
                                "Here's a breakdown of the muscle groups in your ${template.name} workout plan.",
                            muscleGroup: muscleGroupFamilyFrequencies,
                            minimized: false),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      spacing: 30,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 6,
                          children: [
                            CupertinoSlidingSegmentedControl<
                                _OriginalNewValues>(
                              backgroundColor: isDarkMode
                                  ? Theme.of(context).colors.sapphireDark
                                  : Colors.grey.shade200,
                              thumbColor: isDarkMode
                                  ? Theme.of(context).colors.sapphireDark80
                                  : Colors.white,
                              groupValue: _originalNewValues,
                              children: {
                                _OriginalNewValues.originalValues: SizedBox(
                                    width: 100,
                                    child: Text(
                                        _OriginalNewValues.originalValues.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                        textAlign: TextAlign.center)),
                                _OriginalNewValues.newValues: SizedBox(
                                    width: 100,
                                    child: Text(
                                        _OriginalNewValues.newValues.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                        textAlign: TextAlign.center)),
                              },
                              onValueChanged: (_OriginalNewValues? value) {
                                if (value != null) {
                                  setState(() {
                                    _originalNewValues = value;
                                  });
                                }
                              },
                            ),
                            Text(_originalNewValues.description,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                        fontWeight: FontWeight.w400,
                                        color: isDarkMode
                                            ? Colors.white70
                                            : Colors.black)),
                          ],
                        ),
                        ExerciseLogListView(
                          exerciseLogs: exerciseLogsToViewModels(
                              exerciseLogs: exerciseTemplates),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ));
  }

  void _showLoadingScreen() {
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

  void _showLogsForDate(
      BuildContext context, DateTime date, List<RoutineLogDto> allLogs) {
    final logsForDate =
        allLogs.where((log) => log.startTime.isSameDayMonthYear(date)).toList();
    final hasLogs = logsForDate.isNotEmpty;

    // Determine date label
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final selectedDate = DateTime(date.year, date.month, date.day);

    final isToday = selectedDate == today;

    String dateLabel;
    if (isToday) {
      dateLabel = 'Today';
    } else if (selectedDate == yesterday) {
      dateLabel = 'Yesterday';
    } else {
      dateLabel = DateFormat('EEEE, MMM d').format(date);
    }

    showAppBottomSheet(
      context: context,
      isScrollControlled: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with date
            Text(
              dateLabel,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Text(
              DateFormat('MMM d, yyyy').format(date),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade400,
                  ),
            ),
            const SizedBox(height: 16),
            // Logs list
            if (hasLogs)
              ...logsForDate.map((log) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: RoutineLogWidget(
                      log: log,
                      trailing: DateFormat.jm().format(log.startTime),
                      onTap: () {
                        Navigator.pop(context);
                        navigateToRoutineLogPreview(context: context, log: log);
                      },
                    ),
                  ))
            else
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No workouts logged on this day',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey.shade400,
                        ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _deleteRoutine({required RoutineTemplateDto template}) async {
    try {
      await Provider.of<SupabaseExerciseAndRoutineController>(context,
              listen: false)
          .removeTemplate(template: template);
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showSnackbar(context: context, message: "Unable to remove workout");
      }
    } finally {
      _toggleLoadingState();
    }
  }

  void _toggleLoadingState() {
    setState(() {
      _loading = !_loading;
    });
  }

  void _navigateToRoutineTemplateEditor() async {
    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);
    final template = controller.templateWhere(id: widget.id);

    if (template != null) {
      final copyOfTemplate = template.copyWith();
      final arguments = RoutineTemplateArguments(
          template: copyOfTemplate, planId: copyOfTemplate.planId);
      await navigateToRoutineTemplateEditor(
          context: context, arguments: arguments);
      // No need to update state - controller will notify listeners
    }
  }

  void _launchRoutineLogEditor({required List<MuscleGroup> muscleGroups}) {
    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);
    final template = controller.templateWhere(id: widget.id);

    if (template != null) {
      final log = template.toLog();
      final arguments =
          RoutineLogArguments(log: log, editorMode: RoutineEditorMode.log);
      navigateToRoutineLogEditor(context: context, arguments: arguments);
    }
  }

  void _createTemplate({bool copy = false}) async {
    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);
    final template = controller.templateWhere(id: widget.id);
    if (template != null) {
      _showLoadingScreen();

      try {
        final exercises = template.exerciseTemplates.map((exerciseLog) {
          final uncheckedSets = exerciseLog.sets
              .map((set) => set.copyWith(checked: false))
              .toList();
          return exerciseLog.copyWith(sets: uncheckedSets);
        }).toList();
        final templateToBeCreated = RoutineTemplateDto(
            id: "",
            name: copy ? "Copy of ${template.name}" : template.name,
            notes: template.notes,
            exerciseTemplates: exercises,
            planId: template.planId);

        final createdTemplate =
            await Provider.of<SupabaseExerciseAndRoutineController>(context,
                    listen: false)
                .saveTemplate(templateDto: templateToBeCreated);
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
              message: "Oops, we are unable to create your template");
        }
      } finally {
        _hideLoadingScreen();
      }
    }
  }

  void _showMenuBottomSheet({required RoutinePlanDto? planDto}) {
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
                  title: Text("Edit",
                      style: Theme.of(context).textTheme.bodyLarge),
                  onTap: () {
                    Navigator.of(context).pop();
                    _navigateToRoutineTemplateEditor();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const FaIcon(
                    FontAwesomeIcons.copy,
                    size: 18,
                  ),
                  horizontalTitleGap: 6,
                  title: Text("Copy",
                      style: Theme.of(context).textTheme.bodyLarge),
                  onTap: () {
                    Navigator.of(context).pop();
                    _createTemplate(copy: true);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: FaIcon(
                    FontAwesomeIcons.arrowRightArrowLeft,
                    size: 18,
                    color: Colors.white,
                  ),
                  horizontalTitleGap: 6,
                  title: Text("Move to another plan",
                      style: Theme.of(context).textTheme.bodyLarge),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showPlanPicker();
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const FaIcon(
                    FontAwesomeIcons.trash,
                    size: 16,
                    color: Colors.redAccent,
                  ),
                  horizontalTitleGap: 6,
                  title: Text("Delete",
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: Colors.red)),
                  onTap: () {
                    Navigator.of(context).pop();

                    final controller =
                        Provider.of<SupabaseExerciseAndRoutineController>(
                            context,
                            listen: false);
                    final template = controller.templateWhere(id: widget.id);

                    if (template != null) {
                      showBottomSheetWithMultiActions(
                          context: context,
                          title: "Delete workout?",
                          description: planDto != null
                              ? "Are you sure you want to delete this workout and remove it from ${planDto.name}?"
                              : "Are you sure you want to delete this workout?",
                          leftAction: Navigator.of(context).pop,
                          rightAction: () {
                            context.pop();
                            _toggleLoadingState();
                            _deleteRoutine(template: template);
                          },
                          leftActionLabel: 'Cancel',
                          rightActionLabel: 'Delete',
                          isRightActionDestructive: true);
                    }
                  },
                )
              ]),
        ));
  }

  void _showPlanPicker() {
    final exerciseAndRoutineController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);
    final template = exerciseAndRoutineController.templateWhere(id: widget.id);
    final plans = exerciseAndRoutineController.plans;

    if (template != null) {
      showAppBottomSheet(
        context: context,
        isScrollControlled: false,
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: PlanPicker(
            title: "Move ${template.name} to . . .",
            plans: plans,
            onSelect: (selectedPlan) async {
              Navigator.of(context).pop();

              final templateProvider =
                  Provider.of<SupabaseExerciseAndRoutineController>(context,
                      listen: false);

              final updatedRoutineTemplate =
                  template.copyWith(planId: selectedPlan.id);

              await templateProvider.updateTemplate(
                  template: updatedRoutineTemplate);

              if (mounted) {
                showSnackbar(
                    context: context,
                    message: "Add ${template.name} to ${selectedPlan.name}");
              }
            },
          ),
        ),
      );
    }
  }
}

class RecoveryResult {
  final double recoveryPercentage;
  final MuscleGroup muscleGroup;
  final DateTime lastTrainingTime;
  final String description;

  RecoveryResult(
      {required this.recoveryPercentage,
      required this.muscleGroup,
      required this.lastTrainingTime,
      required this.description});

  @override
  String toString() {
    return 'RecoveryResult{recoveryPercentage: $recoveryPercentage, muscleGroup: $muscleGroup, lastTrainingTime: $lastTrainingTime, desciption: $description}';
  }
}
