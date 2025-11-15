import 'dart:convert';

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
import 'package:tracker_app/shared_prefs.dart';
import 'package:tracker_app/utils/dialog_utils.dart';
import 'package:tracker_app/utils/general_utils.dart';
import 'package:tracker_app/utils/navigation_utils.dart';
import 'package:tracker_app/widgets/bottom_sheets/app_bottom_sheet.dart';
import 'package:tracker_app/widgets/buttons/opacity_button_widget_two.dart';
import 'package:tracker_app/widgets/routine/preview/routine_log_widget.dart';
import 'package:tracker_app/widgets/routine/preview/routine_plan_grid_item.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

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

class _OverviewScreenState extends State<OverviewScreen>
    with WidgetsBindingObserver {
  bool _loading = false;
  bool _lastCachedSessionState = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastCachedSessionState = _hasCachedSession();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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

  bool _hasCachedSession() {
    return SharedPrefs().routineLog.isNotEmpty;
  }

  void _showRetryBottomSheet() {
    final cache = SharedPrefs().routineLog;
    if (cache.isEmpty) return;

    try {
      final json = jsonDecode(cache);
      final routineLog = RoutineLogDto.fromJson(json: json);

      showAppBottomSheet(
        context: context,
        isScrollControlled: false,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    color: Theme.of(context).colors.vibrantAccent,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Unsaved Workout',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'You have a workout session that failed to sync:',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      routineLog.name,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${routineLog.exerciseLogs.length} exercises • ${DateFormat('MMM d, y').format(routineLog.startTime)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OpacityButtonWidgetTwo(
                      label: 'Discard',
                      buttonColor: Colors.red,
                      onPressed: () => _discardCachedSession(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OpacityButtonWidgetTwo(
                      label: 'Retry Sync',
                      buttonColor: Theme.of(context).colors.vibrantAccent,
                      onPressed: () => _retryCachedSession(routineLog),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('[Retry] Error showing retry sheet: $e');
    }
  }

  void _discardCachedSession() {
    Navigator.of(context).pop(); // Close bottom sheet
    
    // Clear the cached workout
    SharedPrefs().remove(key: SharedPrefs().routineLogKey);
    setState(() {}); // Refresh to hide notification icon
    
    if (mounted) {
      showSnackbar(
        context: context,
        message: 'Workout discarded',
      );
    }
  }

  Future<void> _retryCachedSession(RoutineLogDto routineLog) async {
    Navigator.of(context).pop(); // Close bottom sheet

    final controller = context.read<SupabaseExerciseAndRoutineController>();

    // Check if this log already exists in the database
    final existingLog = controller.logWhereId(id: routineLog.id);

    if (existingLog != null) {
      // Log already exists - just clear the cache
      SharedPrefs().remove(key: SharedPrefs().routineLogKey);
      setState(() {}); // Refresh to hide notification icon
      if (mounted) {
        showSnackbar(
          context: context,
          message: 'Workout was already saved!',
        );
      }
      return;
    }

    // Try to save the cached workout
    final savedLog = await controller.saveLog(logDto: routineLog);

    // Clear cache only if save succeeded
    if (savedLog != null) {
      SharedPrefs().remove(key: SharedPrefs().routineLogKey);
      setState(() {}); // Refresh to hide notification icon
      if (mounted) {
        showSnackbar(
          context: context,
          message: 'Session saved successfully!',
        );
      }
    } else {
      if (mounted) {
        showSnackbar(
          context: context,
          message: 'Failed to sync. Please try again later.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return TRKRLoadingScreen(action: _hideLoadingScreen);

    final hasCachedSession = _hasCachedSession();

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
