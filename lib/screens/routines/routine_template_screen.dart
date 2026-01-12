import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:provider/provider.dart';
import 'package:trainware/extensions/datetime/datetime_extension.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import '../../dtos/appsync/routine_plan_dto.dart';
import '../../dtos/appsync/routine_template_dto.dart';
import '../../dtos/viewmodels/routine_log_arguments.dart';
import '../../dtos/viewmodels/routine_plan_arguments.dart';
import '../../dtos/viewmodels/routine_template_arguments.dart';
import '../../enums/routine_editor_type_enums.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/exercise_logs_utils.dart';
import '../../utils/general_utils.dart';
import '../../utils/navigation_utils.dart';
import '../../utils/editor_bottom_sheet.dart';
import '../../utils/notifications_utils.dart';
import '../../utils/unsaved_workout_utils.dart';
import '../../extensions/duration_extension.dart';
import '../../shared_prefs.dart';
import '../../utils/string_utils.dart';
import '../../widgets/backgrounds/trkr_loading_screen.dart';
import '../../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../../widgets/calendar/calendar.dart';
import '../../widgets/chip_one.dart';
import '../../dtos/appsync/routine_log_dto.dart';
import '../../widgets/icons/custom_icon.dart';
import '../../widgets/routine/preview/exercise_log_listview.dart';
import '../../widgets/routine/preview/plan_picker.dart';
import '../../widgets/routine/preview/routine_log_widget.dart';
import '../../widgets/empty_states/list_empty_state.dart';
import '../../utils/name_notes_bottom_sheet.dart';

enum _OriginalNewValues {
  originalValues(
    name: "Original Values",
  ),
  newValues(
    name: "Last Session",
  );

  const _OriginalNewValues({required this.name});

  final String name;
}

class RoutineTemplateScreen extends StatefulWidget {
  static const routeName = '/routine_template_screen';

  final String id;
  final ScrollController? scrollController;

  const RoutineTemplateScreen(
      {super.key, required this.id, this.scrollController});

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

    // Get the plan this template belongs to
    final plan = exerciseAndRoutineController.planWhere(id: template.planId);

    // Check if this template belongs to a system plan
    final isSystemTemplate = plan?.isSystemPlan ?? false;

    final allLogsForTemplate = exerciseAndRoutineController
        .whereLogsWithTemplateId(templateId: template.id)
        .map((log) => routineWithLoggedExercises(log: log))
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

    final totalSets = template.exerciseTemplates
        .fold<int>(0, (sum, exercise) => sum + exercise.sets.length);

    return Scaffold(
        floatingActionButton: FloatingActionButton(
            heroTag: UniqueKey,
            backgroundColor: themeGradient(context: context).colors.first,
            elevation: 8.0,
            onPressed: () => _launchRoutineLogEditor(),
            child: const FaIcon(FontAwesomeIcons.play, size: 24)),
        body: Container(
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: themeGradient(context: context),
          ),
          child: SafeArea(
            bottom: false,
            minimum: const EdgeInsets.only(top: 10.0),
            child: SingleChildScrollView(
              controller: widget.scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                        top: 12.0, left: 10.0, right: 10.0),
                    child: Column(
                      spacing: 20,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    template.name,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      height: 1.5,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  if (isSystemTemplate)
                                    Text(
                                      'Not Athletes',
                                      style: TextStyle(
                                        fontFamily: 'GroutpixFlow',
                                        color: Colors.blueGrey.shade400,
                                        fontSize: 14,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (!isSystemTemplate)
                              IconButton(
                                onPressed: () =>
                                    _showMenuBottomSheet(planDto: plan),
                                icon: const FaIcon(
                                    FontAwesomeIcons.ellipsisVertical),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                          ],
                        ),
                        if (template.notes.isNotEmpty)
                          Text(
                            template.notes,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDarkMode ? Colors.white70 : Colors.black,
                              height: 1.8,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        Row(
                          spacing: 8,
                          children: [
                            ChipOne(
                                label:
                                    "${template.exerciseTemplates.length} ${pluralize(word: "Exercise", count: template.exerciseTemplates.length)}",
                                child: CustomIcon(
                                    FontAwesomeIcons.personWalking,
                                    color: Theme.of(context)
                                        .colors
                                        .vibrantAccent)),
                            ChipOne(
                                label:
                                    "$totalSets ${pluralize(word: "Set", count: totalSets)}",
                                child: CustomIcon(FontAwesomeIcons.hashtag,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .secondary)),
                          ],
                        ),
                        Calendar(
                          onSelectDate: (date) => _showLogsForDate(
                              context, date, allLogsForTemplate),
                          logs: allLogsForTemplate,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (template.exerciseTemplates.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        spacing: 20,
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
                                          _OriginalNewValues
                                              .originalValues.name,
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
                            ],
                          ),
                          ExerciseLogListView(
                            exerciseLogs: exerciseTemplates,
                            scrollable: false,
                            controller: null,
                          ),
                        ],
                      ),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10.0, vertical: 40.0),
                      child: const ListEmptyState(
                        message:
                            "It might feel quiet now, but tap the + button to add exercises to this workout.",
                      ),
                    ),
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
    final controller = context.read<SupabaseExerciseAndRoutineController>();
    final logsForDate =
        allLogs.where((log) => log.startTime.isSameDayMonthYear(date)).toList();
    final hasLogs = logsForDate.isNotEmpty;

    // Determine date label (Today, Yesterday, or full date)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final selectedDate = DateTime(date.year, date.month, date.day);

    final isToday = selectedDate == today;
    final isFuture = selectedDate.isAfter(today);

    // Check if this is a predicted training day
    final historicDates = controller.logs.map((log) => log.startTime).toList();
    final todayStart = DateTime(now.year, now.month, now.day);
    final endOfYear = DateTime(now.year, 12, 31);
    final daysAhead = endOfYear.difference(todayStart).inDays;
    final predictedDates = getPredictedTrainingDates(
      historicDateTimes: historicDates,
      daysAhead: daysAhead,
    );
    // Check if this is a predicted training day (today or future, no existing log)
    final isPredicted = (isToday || isFuture) &&
        predictedDates.contains(selectedDate) &&
        !hasLogs;

    String dateLabel;
    if (isToday) {
      dateLabel = 'Today';
    } else if (selectedDate == yesterday) {
      dateLabel = 'Yesterday';
    } else {
      dateLabel = DateFormat('EEEE').format(date);
    }

    showEditorBottomSheet(
      context: context,
      builder: (sheetContext, scrollController) {
        final isDarkMode = Theme.of(sheetContext).brightness == Brightness.dark;

        return Column(
          children: [
            // Header row with date and "Log workout" button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date display
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateLabel,
                          style: Theme.of(sheetContext)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          DateFormat('MMMM d').format(date),
                          style: Theme.of(sheetContext)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Colors.grey.shade400,
                              ),
                        ),
                      ],
                    ),
                  ),
                  // Log workout button (only show for today)
                  if (isToday)
                    IconButton(
                      onPressed: () {
                        Navigator.pop(sheetContext); // Close bottom sheet
                        logEmptyRoutine(context: context);
                      },
                      icon: FaIcon(
                        FontAwesomeIcons.circlePlus,
                        size: 22,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: hasLogs
                  ? ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: logsForDate.length,
                      itemBuilder: (context, index) {
                        final log = logsForDate[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: RoutineLogWidget(
                            log: log,
                            trailing: log.duration().hmsAnalog(),
                            onTap: () {
                              navigateToRoutineLogPreview(
                                context: context,
                                log: log,
                                isEditable: true,
                              );
                            },
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Text(
                        isPredicted
                            ? 'This is a day you\'re likely to train based on your previous workout history.'
                            : 'No workouts logged this date',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.grey.shade400,
                            ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  void _deleteRoutine({required RoutineTemplateDto template}) async {
    try {
      await Provider.of<SupabaseExerciseAndRoutineController>(context,
              listen: false)
          .removeTemplate(template: template);
    } catch (e) {
      if (mounted) {
        showSnackbar(context: context, message: "Unable to remove workout");
      }
    }
  }

  void _showRenameTemplateBottomSheet() {
    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);
    final template = controller.templateWhere(id: widget.id);

    if (template == null) return;

    showNameNotesBottomSheet(
      context: context,
      title: "Edit workout",
      primaryButtonLabel: "Update Workout",
      initialName: template.name,
      initialNotes: template.notes,
      emptyNameMessage: 'Please provide a name for this workout',
    ).then((result) async {
      if (result == null) return;
      final updated = template.copyWith(
        name: result.name,
        notes: result.notes,
      );
      await controller.updateTemplate(template: updated);
    });
  }

  Future<void> _navigateToRoutineTemplateEditor() async {
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

  void _launchRoutineLogEditor() {
    // Prevent starting a new live session when there's an unsaved one
    if (SharedPrefs().routineLog.isNotEmpty) {
      showUnsavedWorkoutBottomSheet(context);
      return;
    }

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

  Future<void> _createTemplate({bool copy = false}) async {
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
    final exerciseAndRoutineController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);
    final template = exerciseAndRoutineController.templateWhere(id: widget.id);
    final plan = template != null
        ? exerciseAndRoutineController.planWhere(id: template.planId)
        : null;
    final isSystemTemplate = plan?.isSystemPlan ?? false;

    showAppBottomSheet(
        context: context,
        isScrollControlled: false,
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isSystemTemplate) ...[
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const FaIcon(
                      FontAwesomeIcons.circlePlus,
                      size: 22,
                    ),
                    horizontalTitleGap: 10,
                    title: Text("Add exercises",
                        style: Theme.of(context).textTheme.bodyLarge),
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _navigateToRoutineTemplateEditor();
                      if (mounted) {
                        _showMenuBottomSheet(planDto: planDto);
                      }
                    },
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const FaIcon(
                      FontAwesomeIcons.penToSquare,
                      size: 18,
                    ),
                    horizontalTitleGap: 10,
                    title: Text("Edit",
                        style: Theme.of(context).textTheme.bodyLarge),
                    onTap: () async {
                      Navigator.of(context).pop();
                      _showRenameTemplateBottomSheet();
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
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _createTemplate(copy: true);
                      if (mounted) {
                        _showMenuBottomSheet(planDto: planDto);
                      }
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

                      if (template != null) {
                        showBottomSheetWithSingleAction(
                            context: context,
                            title: "Delete workout?",
                            description: planDto != null
                                ? "Are you sure you want to delete this workout and remove it from ${planDto.name}?"
                                : "Are you sure you want to delete this workout?",
                            action: () {
                              Navigator.of(context).pop();
                              _deleteRoutine(template: template);
                            },
                            actionLabel: 'Delete',
                            isDestructive: true);
                      }
                    },
                  ),
                ] else
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const FaIcon(
                      FontAwesomeIcons.shield,
                      size: 18,
                      color: Colors.grey,
                    ),
                    horizontalTitleGap: 6,
                    title: Text("Read-only workout",
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey)),
                    subtitle: Text(
                      "This is a system workout. You can log sessions but cannot edit or delete it.",
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Colors.grey.shade600),
                    ),
                  ),
              ]),
        ));
  }

  void _showPlanPicker() {
    final exerciseAndRoutineController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);
    final template = exerciseAndRoutineController.templateWhere(id: widget.id);
    final allPlans = exerciseAndRoutineController.plans;

    if (template != null) {
      // Filter out plans the template already belongs to and system plans
      final eligiblePlans = allPlans
          .where((plan) => plan.id != template.planId && !plan.isSystemPlan)
          .toList();

      showAppBottomSheet(
        context: context,
        isScrollControlled: false,
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: PlanPicker(
            title: "Move ${template.name} to . . .",
            plans: eligiblePlans,
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
                    message: "Moved ${template.name} to ${selectedPlan.name}");
              }
            },
            onCreatePlan: () async {
              Navigator.of(context).pop();
              final arguments = RoutinePlanArguments(
                  plan: RoutinePlanDto(id: "", name: "", notes: ""));
              final newPlan = await navigateToRoutinePlanEditor(
                context: context,
                arguments: arguments,
              );
              if (newPlan != null && mounted) {
                final templateProvider =
                    Provider.of<SupabaseExerciseAndRoutineController>(context,
                        listen: false);
                final updatedRoutineTemplate =
                    template.copyWith(planId: newPlan.id);
                await templateProvider.updateTemplate(
                    template: updatedRoutineTemplate);
                if (mounted) {
                  showSnackbar(
                      context: context,
                      message: "Moved ${template.name} to ${newPlan.name}");
                }
              }
            },
          ),
        ),
      );
    }
  }
}
