import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:trainware/controllers/access_controller.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/shared_prefs.dart';
import 'package:trainware/utils/calendar_date_logs_sheet.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/utils/notifications_utils.dart';
import 'package:trainware/utils/route_observer.dart';
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
  bool _routeSubscribed = false;
  bool _settingsOverlayActive = true; // Settings visible by default

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _lastCachedSessionState = _hasCachedSession();
    _sharedPrefs.routineLogRevision.addListener(_handleRoutineLogChanged);
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
    final hasSelectedClient =
        context.read<ClientOverrideController>().hasSelectedClient;

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

    showCalendarDateLogsSheet(
      context: context,
      date: date,
      logs: logs,
      dateLabel: dateLabel,
      isToday: isToday,
      isPredicted: isPredicted,
      showLogWorkoutButton: !hasSelectedClient,
    );
  }

  void _hideLoadingScreen() {
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }
}
