import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';
import 'package:trainware/dtos/viewmodels/past_routine_log_arguments.dart';
import 'package:trainware/extensions/duration_extension.dart';
import 'package:trainware/shared_prefs.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/utils/navigation_utils.dart';
import 'package:trainware/utils/notifications_utils.dart';
import 'package:trainware/utils/route_observer.dart';
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';
import 'package:trainware/widgets/routine/preview/routine_log_widget.dart';
import '../utils/unsaved_workout_utils.dart';
import '../widgets/backgrounds/trkr_loading_screen.dart';
import '../widgets/calendar/infinite_calendar.dart';
import '../screens/preferences/settings_screen.dart';

class OverviewScreen extends StatefulWidget {
  static const routeName = '/overview_screen';

  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen>
    with WidgetsBindingObserver, RouteAware {
  final SharedPrefs _sharedPrefs = SharedPrefs();
  bool _loading = false;
  bool _lastCachedSessionState = false;
  DateTime _currentVisibleMonth =
      DateTime(DateTime.now().year, DateTime.now().month);
  bool _routeSubscribed = false;
  bool _settingsOverlayActive = true; // Settings visible by default

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
    if (_routeSubscribed) {
      appRouteObserver.unsubscribe(this);
      _routeSubscribed = false;
    }
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
  void didPush() {
    // Settings overlay removed - only show on explicit tap
  }

  @override
  void didPopNext() {
    // Settings overlay removed - only show on explicit tap
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_routeSubscribed) {
      final route = ModalRoute.of(context);
      if (route is PageRoute) {
        appRouteObserver.subscribe(this, route);
        _routeSubscribed = true;
      }
    }
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

  void _toggleSettingsOverlay() {
    setState(() {
      _settingsOverlayActive = !_settingsOverlayActive;
    });
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
              onMonthChanged: (monthStart) {
                if (!mounted) return;
                setState(() {
                  _currentVisibleMonth =
                      DateTime(monthStart.year, monthStart.month);
                });
              },
            ),
          ),
          // Month summary overlay (center)
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 16,
            left: 0,
            right: 0,
            child: Center(
              child: Consumer<SupabaseExerciseAndRoutineController>(
                builder: (context, controller, _) {
                  final logs = controller.logs;
                  final monthLogs = logs.where((log) {
                    final dt = log.startTime;
                    return dt.year == _currentVisibleMonth.year &&
                        dt.month == _currentVisibleMonth.month;
                  }).length;

                  final monthLabel =
                      DateFormat('MMM yyyy').format(_currentVisibleMonth);
                  final countLabel =
                      monthLogs == 1 ? '1 session' : '$monthLogs sessions';

                  return Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          monthLabel,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 18,
                                  ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          countLabel,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 14,
                                  ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          // Notification icon overlay (only when cached session exists)
          if (hasCachedSession)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 72, // Position to left of settings icon
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFf59e0b).withValues(alpha: 0.5),
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
                  icon: const FaIcon(FontAwesomeIcons.grip, size: 18),
                  onPressed: _toggleSettingsOverlay,
                  tooltip: 'Dashboard',
                  color: Colors.white,
                  padding: const EdgeInsets.all(12),
                  constraints: const BoxConstraints(),
                ),
              ),
            ),
          ),
          // Settings screen overlay
          if (_settingsOverlayActive)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.25),
                ),
              ),
            ),
          if (_settingsOverlayActive)
            SettingsScreen(
              onClose: _toggleSettingsOverlay,
            ),
        ],
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
                  // Log workout button (hide for future dates)
                  if (!isFuture)
                    IconButton(
                      onPressed: () {
                        Navigator.pop(sheetContext); // Close bottom sheet
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

  void _hideLoadingScreen() {
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }
}
