import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tracker_app/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:tracker_app/dtos/appsync/routine_log_dto.dart';
import 'package:tracker_app/dtos/appsync/routine_plan_dto.dart';
import 'package:tracker_app/dtos/viewmodels/past_routine_log_arguments.dart';
import 'package:tracker_app/dtos/viewmodels/routine_plan_arguments.dart';
import 'package:tracker_app/extensions/duration_extension.dart';
import 'package:tracker_app/utils/general_utils.dart';
import 'package:tracker_app/utils/navigation_utils.dart';
import 'package:tracker_app/widgets/routine/preview/routine_log_widget.dart';
import 'package:tracker_app/widgets/routine/preview/routine_plan_grid_item.dart';

import '../screens/routines/routine_plan.dart';
import '../widgets/backgrounds/trkr_loading_screen.dart';
import '../widgets/calendar/infinite_calendar.dart';
import '../widgets/custom_logo.dart';

class OverviewScreen extends StatefulWidget {
  static const routeName = '/overview_screen';

  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    if (_loading) return TRKRLoadingScreen(action: _hideLoadingScreen);

    return Scaffold(
      backgroundColor: appBarBackgroundColor(context: context),
      body: Stack(
        children: [
          SafeArea(
            bottom: false,
            child: InfiniteCalendar(
              onDateTap: (date) => _showLogsForDate(context, date),
            ),
          ),
          // Settings icon overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Material(
                color: Colors.transparent,
                child: IconButton(
                  icon: const FaIcon(FontAwesomeIcons.gear, size: 18),
                  onPressed: () => navigateToSettings(context: context),
                  tooltip: 'Settings',
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPlansBottomSheet(context),
        backgroundColor: themeGradient(context: context).colors.first,
        elevation: 8.0,
        child: const CustomLogo(size: 32),
      ),
    );
  }

  void _showLogsForDate(BuildContext context, DateTime date) {
    final controller = context.read<SupabaseExerciseAndRoutineController>();
    final logs = controller.whereLogsIsSameDay(dateTime: date).toList();
    final hasLogs = logs.isNotEmpty;

    // Determine date label (Today, Yesterday, or full date)
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final selectedDate = DateTime(date.year, date.month, date.day);

    final isToday = selectedDate == today;
    final isPast = selectedDate.isBefore(today);
    final isFuture = selectedDate.isAfter(today);

    String dateLabel;
    if (isToday) {
      dateLabel = 'Today';
    } else if (selectedDate == yesterday) {
      dateLabel = 'Yesterday';
    } else {
      dateLabel = DateFormat('EEEE').format(date);
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;

          return Container(
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF1A1F2E) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              gradient: isDarkMode ? themeGradient(context: context) : null,
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header row with date and "Log workout" button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
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
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              DateFormat('MMMM d').format(date),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.grey.shade400,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      // Log workout button (hide for future dates)
                      if (!isFuture)
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context); // Close bottom sheet
                            if (isToday) {
                              // Log a fresh session for today
                              logEmptyRoutine(context: context);
                            } else if (isPast) {
                              // Log a past session for the selected date
                              _logPastSessionForDate(context, date);
                            }
                          },
                          icon: const FaIcon(FontAwesomeIcons.plus, size: 18),
                          color: isDarkMode ? Colors.white : Colors.black,
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
                          itemCount: logs.length,
                          itemBuilder: (context, index) {
                            final log = logs[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: RoutineLogWidget(
                                log: log,
                                trailing: log.duration().hmsAnalog(),
                                onTap: () {
                                  Navigator.pop(context); // Close bottom sheet
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
                            'No workouts logged this date',
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.grey.shade400,
                                    ),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _logPastSessionForDate(BuildContext context, DateTime date) {
    final log = RoutineLogDto(
      id: "",
      templateId: "",
      name: "${timeOfDay()} Session",
      exerciseLogs: [],
      notes: "",
      startTime: date,
      endTime: date,
    );
    final arguments = PastRoutineLogArguments(log: log);
    navigateToPastRoutineLogEditor(context: context, arguments: arguments);
  }

  void _showPlansBottomSheet(BuildContext context) {
    final controller = context.read<SupabaseExerciseAndRoutineController>();
    final plans = controller.plans;
    final hasPlans = plans.isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;

          return Container(
            decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF1A1F2E) : Colors.white,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                gradient: isDarkMode ? themeGradient(context: context) : null),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header row with title and "Create plan" button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and subtitle
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Plans',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            Text(
                              'Your workout plans',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.grey.shade400,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      // Create plan button
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context); // Close bottom sheet
                          _createNewPlan(context);
                        },
                        icon: const FaIcon(FontAwesomeIcons.plus, size: 18),
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: hasPlans
                      ? GridView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.85,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                          ),
                          itemCount: plans.length,
                          itemBuilder: (context, index) {
                            final plan = plans[index];
                            return RoutinePlanGridItemWidget(
                              plan: plan,
                              onTap: () {
                                Navigator.pop(context); // Close bottom sheet
                                navigateWithSlideTransition(
                                  context: context,
                                  child: RoutinePlanScreen(id: plan.id),
                                );
                              },
                            );
                          },
                        )
                      : Center(
                          child: Text(
                            'No plans created yet',
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.grey.shade400,
                                    ),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _createNewPlan(BuildContext context) {
    final plan = RoutinePlanDto(
      id: "",
      name: "",
      notes: "",
    );
    final arguments = RoutinePlanArguments(plan: plan);
    navigateToRoutinePlanEditor(context: context, arguments: arguments);
  }

  void _hideLoadingScreen() {
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }
}
