import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:provider/provider.dart';
import 'package:tracker_app/extensions/datetime/datetime_extension.dart';
import 'package:tracker_app/utils/string_utils.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

import 'package:tracker_app/controllers/supabase_exercise_and_routine_controller.dart';
import '../../dtos/appsync/routine_plan_dto.dart';
import '../../dtos/appsync/routine_template_dto.dart';
import '../../dtos/viewmodels/routine_plan_arguments.dart';
import '../../dtos/viewmodels/routine_template_arguments.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/general_utils.dart';
import '../../utils/navigation_utils.dart';
import '../../widgets/backgrounds/trkr_loading_screen.dart';
import '../../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../../widgets/calendar/calendar.dart';
import '../../widgets/chip_one.dart';
import '../../dtos/appsync/routine_log_dto.dart';
import '../../widgets/empty_states/no_list_empty_state.dart';
import '../../widgets/empty_states/not_found.dart';
import '../../widgets/icons/custom_icon.dart';
import '../../widgets/routine/preview/routine_log_widget.dart';
import '../../widgets/routine/preview/routine_template_grid_item.dart';
import '../../widgets/routine/preview/plan_picker.dart';
import '../../nudges/plans_nudges.dart';
import '../../widgets/information_containers/transparent_information_container_lite.dart';

class RoutinePlanScreen extends StatefulWidget {
  static const routeName = '/routine_plan_screen';

  final String id;

  const RoutinePlanScreen({super.key, required this.id});

  @override
  State<RoutinePlanScreen> createState() => _RoutinePlanScreenState();
}

class _RoutinePlanScreenState extends State<RoutinePlanScreen> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    if (_loading) return TRKRLoadingScreen(action: _hideLoadingScreen);

    final exerciseAndRoutineController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: true);

    // Reload plan from controller on every build (in case it was updated)
    final plan = exerciseAndRoutineController.planWhere(id: widget.id);

    if (plan == null) return const NotFound();

    if (exerciseAndRoutineController.errorMessage.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showSnackbar(
            context: context,
            message: exerciseAndRoutineController.errorMessage);
      });
    }

    final routineTemplates = exerciseAndRoutineController.templates
        .where((template) => template.planId == plan.id)
        .toList();

    final logs = routineTemplates
        .expand((template) => exerciseAndRoutineController
            .whereLogsWithTemplateId(templateId: template.id))
        .toList();

    final children = routineTemplates
        .mapIndexed(
          (index, template) => GestureDetector(
            onTap: () => navigateToRoutineTemplatePreview(
                context: context, template: template),
            onLongPress: () =>
                _showTemplateMenu(template: template, plan: plan),
            child: RoutineTemplateGridItemWidget(
              template: template.copyWith(notes: template.notes),
              onTap: () => navigateToRoutineTemplatePreview(
                  context: context, template: template),
            ),
          ),
        )
        .toList();

    final exercises = routineTemplates
        .expand((routineTemplate) => routineTemplate.exerciseTemplates);

    return Scaffold(
        appBar: AppBar(
          backgroundColor: appBarBackgroundColor(context: context),
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const FaIcon(FontAwesomeIcons.squareXmark, size: 28),
            onPressed: context.pop,
          ),
          actions: [
            IconButton(
                onPressed: _showMenuBottomSheet,
                icon: const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 22))
          ],
        ),
        body: Container(
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: themeGradient(context: context),
          ),
          child: SafeArea(
            minimum: const EdgeInsets.only(right: 10, left: 10),
            bottom: false,
            child: SingleChildScrollView(
              child: Column(
                  spacing: 16,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Builder(builder: (context) {
                      final controller =
                          Provider.of<SupabaseExerciseAndRoutineController>(
                              context,
                              listen: false);
                      final msg = PlansNudges.build(controller: controller);
                      if (msg == null) return const SizedBox.shrink();
                      return TransparentInformationContainerLite(
                        content: "msg",
                        useOpacity: true,
                      );
                    }),
                    Text(plan.name,
                        style: TextStyle(
                            fontSize: 20,
                            height: 1.5,
                            fontWeight: FontWeight.w900)),
                    Row(spacing: 12, children: [
                      ChipOne(
                        label:
                            '${exercises.length} ${pluralize(word: "Exercise", count: exercises.length)}',
                        child: CustomIcon(FontAwesomeIcons.personWalking,
                            color: Theme.of(context).colors.vibrantAccent),
                      ),
                      ChipOne(
                          label:
                              '${routineTemplates.length} ${pluralize(word: "Session", count: routineTemplates.length)}',
                          child: CustomIcon(FontAwesomeIcons.hashtag,
                              color: Theme.of(context).colorScheme.secondary)),
                    ]),
                    Text(plan.notes.isNotEmpty ? plan.notes : "No notes",
                        style: TextStyle(
                            fontSize: 14,
                            color: isDarkMode ? Colors.white70 : Colors.black,
                            height: 1.8,
                            fontWeight: FontWeight.w400)),
                    Column(
                      spacing: 4,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Calendar(
                          onSelectDate: (date) =>
                              _showLogsForDate(context, date, logs),
                          logs: logs,
                        ),
                      ],
                    ),
                    routineTemplates.isNotEmpty
                        ? GridView.count(
                            shrinkWrap: true,
                            physics: NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            childAspectRatio: 1,
                            mainAxisSpacing: 10.0,
                            crossAxisSpacing: 10.0,
                            children: children)
                        : Padding(
                            padding: const EdgeInsets.symmetric(vertical: 50.0),
                            child: const NoListEmptyState(
                                message:
                                    "It might feel quiet now, but your workout templates will soon appear here."),
                          ),
                  ]),
            ),
          ),
        ));
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

  void _deleteRoutinePlan({required RoutinePlanDto plan}) async {
    try {
      final exerciseAndRoutineController =
          Provider.of<SupabaseExerciseAndRoutineController>(context,
              listen: false);

      final routineTemplates = exerciseAndRoutineController.templates
          .where((template) => template.planId == plan.id)
          .toList();

      await exerciseAndRoutineController.removePlan(plan: plan);

      for (final template in routineTemplates) {
        final templateWithoutPlanId = template.copyWith(planId: "");
        await exerciseAndRoutineController.updateTemplate(
            template: templateWithoutPlanId);
      }

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showSnackbar(context: context, message: "Unable to remove plan");
      }
    } finally {
      _toggleLoadingState();
    }
  }

  void _navigateToRoutinePlanEditor() async {
    final exerciseAndRoutineController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);
    final plan = exerciseAndRoutineController.planWhere(id: widget.id);

    if (plan != null) {
      final copyOfPlan = plan.copyWith();
      final arguments = RoutinePlanArguments(plan: copyOfPlan);
      await navigateToRoutinePlanEditor(context: context, arguments: arguments);
      // No need to update state - controller will notify listeners
    }
  }

  void _toggleLoadingState() {
    setState(() {
      _loading = !_loading;
    });
  }

  void _showTemplateMenu(
      {required RoutineTemplateDto template, required RoutinePlanDto plan}) {
    final exerciseAndRoutineController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);
    final plans = exerciseAndRoutineController.plans;

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
                FontAwesomeIcons.arrowRightArrowLeft,
                size: 18,
              ),
              horizontalTitleGap: 10,
              title: Text("Move to another plan",
                  style: Theme.of(context).textTheme.bodyLarge),
              onTap: () {
                Navigator.of(context).pop();
                _showMoveToPlanPicker(template: template, plans: plans);
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
              title: Text("Remove from plan",
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge
                      ?.copyWith(color: Colors.red)),
              onTap: () {
                Navigator.of(context).pop();
                _removeTemplateFromPlan(template: template);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showMoveToPlanPicker(
      {required RoutineTemplateDto template,
      required List<RoutinePlanDto> plans}) {
    // Filter out the current plan
    final otherPlans = plans.where((p) => p.id != widget.id).toList();

    showAppBottomSheet(
      context: context,
      isScrollControlled: false,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: PlanPicker(
          title: "Move ${template.name} to...",
          plans: otherPlans,
          onSelect: (selectedPlan) async {
            Navigator.of(context).pop();
            await _moveTemplateToPlan(
                template: template, targetPlan: selectedPlan);
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
              await _moveTemplateToPlan(
                  template: template, targetPlan: newPlan);
            }
          },
        ),
      ),
    );
  }

  Future<void> _removeTemplateFromPlan(
      {required RoutineTemplateDto template}) async {
    final templateWithoutPlanId = template.copyWith(planId: "");
    await Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false)
        .updateTemplate(template: templateWithoutPlanId);
  }

  Future<void> _moveTemplateToPlan(
      {required RoutineTemplateDto template,
      required RoutinePlanDto targetPlan}) async {
    final templateWithNewPlanId = template.copyWith(planId: targetPlan.id);
    await Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false)
        .updateTemplate(template: templateWithNewPlanId);

    if (mounted) {
      showSnackbar(
        context: context,
        message: 'Moved to ${targetPlan.name}',
      );
    }
  }

  void _showMenuBottomSheet() {
    final exerciseAndRoutineController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);
    final plan = exerciseAndRoutineController.planWhere(id: widget.id);

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
                      FontAwesomeIcons.circlePlus,
                      size: 18,
                    ),
                    horizontalTitleGap: 6,
                    title: Text("Add new workout",
                        style: Theme.of(context).textTheme.bodyLarge),
                    onTap: () {
                      Navigator.of(context).pop();
                      final arguments =
                          RoutineTemplateArguments(planId: plan?.id ?? "");
                      navigateToRoutineTemplateEditor(
                          context: context, arguments: arguments);
                    }),
                ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const FaIcon(
                      FontAwesomeIcons.penToSquare,
                      size: 18,
                    ),
                    horizontalTitleGap: 6,
                    title: Text("Edit",
                        style: Theme.of(context).textTheme.bodyLarge),
                    onTap: () {
                      Navigator.of(context).pop();
                      _navigateToRoutinePlanEditor();
                    }),
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

                    if (plan != null) {
                      showBottomSheetWithMultiActions(
                          context: context,
                          title: "Delete plan?",
                          description:
                              "Are you sure you want to delete this plan?",
                          leftAction: Navigator.of(context).pop,
                          rightAction: () {
                            context.pop();
                            _toggleLoadingState();
                            _deleteRoutinePlan(plan: plan);
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
}
