import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';
import 'package:trainware/dtos/appsync/routine_plan_dto.dart';
import 'package:trainware/dtos/viewmodels/past_routine_log_arguments.dart';
import 'package:trainware/dtos/viewmodels/routine_plan_arguments.dart';
import 'package:trainware/extensions/duration_extension.dart';
import 'package:trainware/shared_prefs.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/utils/navigation_utils.dart';
import 'package:trainware/utils/notifications_utils.dart';
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';
import 'package:trainware/widgets/routine/preview/routine_log_widget.dart';
import 'package:trainware/widgets/routine/preview/routine_plan_grid_item.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

import '../screens/routines/routine_plan.dart';
import '../utils/unsaved_workout_utils.dart';
import '../widgets/backgrounds/trkr_loading_screen.dart';
import '../widgets/calendar/infinite_calendar.dart';
import '../widgets/custom_logo.dart';

class OverviewScreen extends StatefulWidget {
  static const routeName = '/overview_screen';

  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen>
    with WidgetsBindingObserver {
  final SharedPrefs _sharedPrefs = SharedPrefs();
  bool _loading = false;
  bool _lastCachedSessionState = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastCachedSessionState = _hasCachedSession();
    _sharedPrefs.routineLogRevision.addListener(_handleRoutineLogChanged);

    // If there's a pending unsaved workout when the overview screen first loads,
    // immediately prompt the user to resolve it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_hasCachedSession()) {
        _showRetryBottomSheet();
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sharedPrefs.routineLogRevision.removeListener(_handleRoutineLogChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh state when app resumes to check cache status
    if (state == AppLifecycleState.resumed && mounted) {
      _checkCacheStatus();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Refresh state when route becomes active to check cache status
    _checkCacheStatus();
  }

  void _checkCacheStatus() {
    if (!mounted) return;
    final currentCachedSessionState = _hasCachedSession();
    // Only rebuild if cache status changed
    if (currentCachedSessionState != _lastCachedSessionState) {
      _lastCachedSessionState = currentCachedSessionState;
      setState(() {});
    }
  }

  void _handleRoutineLogChanged() {
    if (!mounted) return;
    // Defer cache status check to the next frame to avoid setState during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkCacheStatus();
      }
    });
  }

  bool _hasCachedSession() {
    return SharedPrefs().routineLog.isNotEmpty;
  }

  void _showRetryBottomSheet() {
    showUnsavedWorkoutBottomSheet(context);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return TRKRLoadingScreen(action: _hideLoadingScreen);

    // Check cache status and update state if it changed
    // This ensures the notification icon updates when navigating back from editor
    final currentCachedSessionState = _hasCachedSession();
    if (currentCachedSessionState != _lastCachedSessionState) {
      // Update state in post-frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _lastCachedSessionState = currentCachedSessionState;
          setState(() {});
        }
      });
    }

    final hasCachedSession = currentCachedSessionState;

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
          // Notification icon overlay (only when cached session exists)
          if (hasCachedSession)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 72, // Position to left of settings icon
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colors
                      .vibrantAccent
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: IconButton(
                    icon: const FaIcon(FontAwesomeIcons.bell, size: 18),
                    onPressed: _showRetryBottomSheet,
                    tooltip: 'Unsaved workout',
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    constraints: const BoxConstraints(),
                  ),
                ),
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

    // Check if this is a predicted training day
    final historicDates = controller.logs.map((log) => log.startTime).toList();
    final predictedDates = getPredictedTrainingDates(
      historicDateTimes: historicDates,
      daysAhead: 7,
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

    showAppBottomSheet(
      context: context,
      isDraggable: true,
      builder: (context, scrollController) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

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
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          DateFormat('MMMM d').format(date),
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                      icon: FaIcon(
                        FontAwesomeIcons.circlePlus,
                        size: 18,
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
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
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

  void _logPastSessionForDate(BuildContext context, DateTime date) {
    final log = RoutineLogDto(
      id: "",
      templateId: "",
      name: "${timeOfDay()} Session",
      exerciseLogs: [],
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

    showAppBottomSheet(
      context: context,
      isDraggable: true,
      builder: (context, scrollController) {
        final isDarkMode = Theme.of(context).brightness == Brightness.dark;

        return Column(
          children: [
            // Header row with title and "Create plan" button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
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
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.grey.shade400,
                                  ),
                        ),
                      ],
                    ),
                  ),
                  // Create plan button
                  IconButton(
                    onPressed: () => _createNewPlan(context),
                    icon: FaIcon(
                      FontAwesomeIcons.circlePlus,
                      size: 18,
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
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

  void _createNewPlan(BuildContext context) async {
    // Close bottom sheet first
    Navigator.pop(context);

    final plan = RoutinePlanDto(
      id: "",
      name: "",
      notes: "",
    );
    final arguments = RoutinePlanArguments(plan: plan);
    final createdPlan = await navigateToRoutinePlanEditor(
        context: context, arguments: arguments);

    // Navigate to the created plan
    if (createdPlan != null && context.mounted) {
      navigateWithSlideTransition(
        context: context,
        child: RoutinePlanScreen(id: createdPlan.id),
      );
    }
  }

  void _hideLoadingScreen() {
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }
}
