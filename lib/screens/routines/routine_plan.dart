import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:trainware/utils/shell_tab_paths.dart';
import 'package:intl/intl.dart';

import 'package:provider/provider.dart';
import 'package:trainware/extensions/datetime/datetime_extension.dart';
import 'package:trainware/utils/string_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/widgets/loading/coach_loading_overlay.dart';
import '../../dtos/appsync/routine_plan_dto.dart';
import '../../dtos/appsync/routine_template_dto.dart';
import '../../dtos/viewmodels/routine_plan_arguments.dart';
import '../../utils/dialog_utils.dart';
import '../../controllers/access_controller.dart';
import '../../utils/app_privileges.dart';
import '../../utils/general_utils.dart';
import '../../utils/navigation_utils.dart';
import '../../utils/notifications_utils.dart';
import '../../widgets/backgrounds/trkr_loading_screen.dart';
import '../../utils/calendar_date_logs_sheet.dart';
import '../../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../../widgets/calendar/calendar.dart';
import '../../widgets/chip_one.dart';
import '../../dtos/appsync/routine_log_dto.dart';
import '../../widgets/empty_states/illustrated_empty_state.dart';
import '../../widgets/icons/custom_icon.dart';
import '../../widgets/navigation/app_floating_navigation_bar.dart';
import '../../widgets/routine/preview/routine_template_grid_item.dart';
import '../../widgets/routine/plan_workouts_reorder_sheet.dart';
import '../../utils/name_notes_bottom_sheet.dart';

class RoutinePlanScreen extends StatefulWidget {
  static const routeName = '/routine_plan_screen';

  final String id;

  /// When true (shell tab), hide back affordance; use bottom nav instead of pop.
  final bool embeddedInShell;

  const RoutinePlanScreen({
    super.key,
    required this.id,
    this.embeddedInShell = false,
  });

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
    final accessController = context.watch<ClientOverrideController>();
    final hasSelectedClient = accessController.hasSelectedClient;

    // Reload plan from controller on every build (in case it was updated)
    final plan = exerciseAndRoutineController.planWhere(id: widget.id);

    // If deleted while visible, quietly exit instead of flashing "Not Found"
    if (plan == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.embeddedInShell) {
          context.go(kShellRoutinesPath);
          return;
        }
        final navigator = Navigator.maybeOf(context);
        if (navigator != null && navigator.canPop()) {
          context.pop();
        }
      });
      return const SizedBox.shrink();
    }

    if (exerciseAndRoutineController.errorMessage.isNotEmpty) {
      final msg = exerciseAndRoutineController.errorMessage;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showSnackbar(context: context, message: msg);
        exerciseAndRoutineController.clearErrorMessageAfterDisplay();
      });
    }

    final routineTemplates = exerciseAndRoutineController
        .whereTemplatesForPlan(planId: plan.id);

    final logs = routineTemplates
        .expand((template) => exerciseAndRoutineController
            .whereLogsWithTemplateId(templateId: template.id))
        .toList();

    final children = routineTemplates
        .mapIndexed(
          (index, template) => GestureDetector(
            child: RoutineTemplateGridItemWidget(
              template: template,
              plan: plan,
              onTap: () => navigateToRoutineTemplatePreview(
                context: context,
                template: template,
                embeddedInShell: widget.embeddedInShell,
              ),
            ),
          ),
        )
        .toList();

    final bottomNavPad = widget.embeddedInShell
        ? MediaQuery.paddingOf(context).bottom + kAppFloatingNavBarReserveHeight
        : 0.0;

    final exercises = routineTemplates
        .expand((routineTemplate) => routineTemplate.exerciseTemplates);

    return Scaffold(
        appBar: AppBar(
          backgroundColor: appBarBackgroundColor(context: context),
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          automaticallyImplyLeading: !widget.embeddedInShell,
          leading: widget.embeddedInShell
              ? null
              : IconButton(
                  icon: const FaIcon(FontAwesomeIcons.solidCircleXmark, size: 28),
                  onPressed: context.pop,
                ),
          actions: [
            if (!plan.isSystemPlan ||
                hasSelectedClient ||
                AppPrivileges.canCreateManageRoutines)
              IconButton(
                  onPressed: _showMenuBottomSheet,
                  icon:
                      const FaIcon(FontAwesomeIcons.ellipsisVertical, size: 22))
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
                  spacing: 20,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.name,
                          style: const TextStyle(
                            fontSize: 20,
                            height: 1.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          plan.isSystemPlan ? 'Not Athletes' : 'Created by you',
                          style: TextStyle(
                            fontFamily: 'GroutpixFlow',
                            color: Colors.blueGrey.shade400,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      plan.notes.isNotEmpty ? plan.notes : "No notes",
                      style: TextStyle(
                        fontSize: 14,
                        color: isDarkMode ? Colors.white70 : Colors.black,
                        height: 1.8,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
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
                    Calendar(
                      onSelectDate: (date) =>
                          _showLogsForDate(context, date, logs),
                      logs: logs,
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
                        : IllustratedEmptyState(
                            outerVerticalPadding: 24,
                            icon: FontAwesomeIcons.clipboardList,
                            title: 'No workout templates yet',
                            body: AppPrivileges.canCreateManageRoutines
                                ? 'Use the menu (⋯) to add a workout template to this plan.'
                                : 'When your coach adds workouts to this plan, they’ll appear here.',
                          ),
                    SizedBox(height: bottomNavPad),
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

    final hasSelectedClient = context.read<ClientOverrideController>().hasSelectedClient;

    showCalendarDateLogsSheet(
      context: context,
      date: date,
      logs: logsForDate,
      dateLabel: dateLabel,
      isToday: isToday,
      isPredicted: isPredicted,
      showLogWorkoutButton: !hasSelectedClient,
    );
  }

  Future<void> _navigateToRoutinePlanEditor() async {
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

  void _showCreateWorkoutBottomSheet({required RoutinePlanDto plan}) {
    showNameNotesBottomSheet(
      context: context,
      title: "Create workout",
      primaryButtonLabel: "Create Workout",
      emptyNameMessage: 'Please provide a name for this workout',
      compact: true,
    ).then((result) async {
      if (result == null) return;
      if (!mounted) return;
      if (AppConfig.isCoach) showCoachLoadingOverlay(context);
      try {
        final exerciseAndRoutineController =
            Provider.of<SupabaseExerciseAndRoutineController>(context,
                listen: false);
        final template = RoutineTemplateDto(
          id: "",
          name: result.name,
          notes: result.notes,
          exerciseTemplates: const [],
          planId: plan.id,
        );

        await exerciseAndRoutineController.saveTemplate(templateDto: template);
      } finally {
        if (AppConfig.isCoach && mounted) {
          hideCoachLoadingOverlay(context);
        }
      }
    });
  }

  void _showMenuBottomSheet() {
    final exerciseAndRoutineController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);
    final plan = exerciseAndRoutineController.planWhere(id: widget.id);

    if (plan == null) return;

    final templatesInPlan =
        exerciseAndRoutineController.whereTemplatesForPlan(planId: plan.id);

    showAppActionBottomSheet(
        context: context,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!plan.isSystemPlan ||
                    context.read<ClientOverrideController>().hasSelectedClient ||
                    AppPrivileges.canCreateManageRoutines) ...[
                  ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const FaIcon(
                        FontAwesomeIcons.circlePlus,
                        size: 20,
                      ),
                      horizontalTitleGap: 10,
                      title: Text("Add new workout",
                          style: Theme.of(context).textTheme.bodyLarge),
                      onTap: () async {
                        Navigator.of(context).pop();
                        _showCreateWorkoutBottomSheet(plan: plan);
                      }),
                  if (AppConfig.isCoach && templatesInPlan.length >= 2)
                    ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: const FaIcon(
                          FontAwesomeIcons.arrowsUpDownLeftRight,
                          size: 18,
                        ),
                        horizontalTitleGap: 10,
                        title: Text("Reorder workouts",
                            style: Theme.of(context).textTheme.bodyLarge),
                        onTap: () async {
                          Navigator.of(context).pop();
                          await showPlanWorkoutsReorderSheet(
                            context: context,
                            plan: plan,
                            initialOrder: templatesInPlan,
                          );
                        }),
                  if (AppConfig.isCoach)
                    ListTile(
                        dense: true,
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
                          await _navigateToRoutinePlanEditor();
                          if (mounted) {
                            _showMenuBottomSheet();
                          }
                        }),
                ] else
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const FaIcon(
                      FontAwesomeIcons.shield,
                      size: 18,
                      color: Colors.grey,
                    ),
                    horizontalTitleGap: 10,
                    title: Text("Read-only plan",
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey)),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        "This is a system plan. You can log sessions but cannot edit or delete it.",
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
              ]),
        ));
  }
}
