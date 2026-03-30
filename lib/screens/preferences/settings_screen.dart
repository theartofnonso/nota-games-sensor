import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:trainware/controllers/nutrition_log_controller.dart';
import 'package:trainware/dtos/nutrition/nutrition_log_dto.dart';
import 'package:trainware/screens/nutrition/nutrition_tracker_screen.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/config/chat_config.dart';
import 'package:trainware/shared_prefs.dart';
import 'package:trainware/utils/notifications_utils.dart';
import 'package:trainware/utils/app_privileges.dart';

import '../../controllers/supabase_exercise_and_routine_controller.dart';
import '../../controllers/access_controller.dart';
import '../../dtos/appsync/routine_log_dto.dart';
import '../../extensions/duration_extension.dart';
import '../../services/client_subscription_service.dart';
import '../../services/training_prediction_service.dart';
import '../../utils/calendar_date_logs_sheet.dart';
import '../../utils/theme/color_extensions.dart';
import '../../utils/unsaved_workout_utils.dart';
import '../../widgets/backgrounds/trkr_loading_screen.dart';
import '../../widgets/cards/frosted_card.dart';
import '../../widgets/nutrition/calorie_tracking_card.dart';
import '../../widgets/calendar/calendar.dart';
import '../../widgets/buttons/opacity_button_widget_two.dart';
import '../../widgets/home/client_subscribe_prompt_card.dart';
import '../../widgets/navigation/app_floating_navigation_bar.dart';

class SettingsScreen extends StatefulWidget {
  static const routeName = '/settings-screen';

  final VoidCallback? onClose;

  const SettingsScreen({super.key, this.onClose});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _loading = false;

  String _environment = "";
  String _bundleId = "";
  String _deviceToken = "";

  bool _hasCachedSession = false;

  bool _nutritionInitialized = false;

  static const double _sectionSpacing = 16.0;

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;
    if (_loading) {
      return TRKRLoadingScreen(
        action: () {
          if (mounted) {
            setState(() {
              _loading = false;
            });
          }
        },
      );
    }

    final controller = context.watch<SupabaseExerciseAndRoutineController>();
    final logs = controller.logs;
    final yearStats = _YearTrainingStats.fromLogs(logs);
    final yearHoursStats = _YearHoursStats.fromLogs(logs);
    final nextSession = TrainingPredictionService.getNextPredictedSession(logs);
    final predictionInfo = nextSession != null
        ? _PredictionInfo(
            date: nextSession.date,
            time: nextSession.time,
            daysUntilNext: nextSession.daysUntilNext,
          )
        : const _PredictionInfo(date: null, time: null);

    final bottomInset = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Calendar widget at top
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Calendar(
                      logs: logs,
                      onSelectDate: (date) => _showLogsForDate(context, date),
                      onChevronTap: () {
                        if (widget.onClose != null) {
                          widget.onClose!();
                        } else {
                          context.pop();
                        }
                      },
                    ),
                  ),
                  // Unsaved session card
                  if (_hasCachedSession) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: _UnsavedSessionCard(
                        onTap: () =>
                            unawaited(navigateToUnsavedSession(context)),
                      ),
                    ),
                  ],
                  ListenableBuilder(
                    listenable:
                        ClientSubscriptionService.instance.accessRevision,
                    builder: (context, _) {
                      // Clients without subscription: hide (subscribe UX only).
                      // Subscribed clients and coach app: show progress carousel.
                      final hideTrainingInsightsCarousel =
                          AppConfig.isClient &&
                              !ClientSubscriptionService.instance.hasAccess;
                      if (hideTrainingInsightsCarousel) {
                        return const SizedBox.shrink();
                      }
                      return _TrainingInsightsSection(
                        yearStats: yearStats,
                        yearHoursStats: yearHoursStats,
                        predictionInfo: predictionInfo,
                      );
                    },
                  ),
                  SizedBox(height: _sectionSpacing),
                  _NutritionSection(),
                  _SpacerIfNutritionVisible(),
                  SizedBox(height: _sectionSpacing),
                  _buildDebugInfoSection(isDarkMode),
                  SizedBox(height: _sectionSpacing),
                  SizedBox(
                    height: bottomInset + kAppFloatingNavBarReserveHeight + 24,
                  ),
                ],
              ),
            ),
      ),
    );
  }

  void _getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final bundleId = packageInfo.packageName;

    String env;
    if (kDebugMode) {
      env = 'Debug';
    } else if (kProfileMode) {
      env = 'Profile';
    } else {
      env = 'Release';
    }

    String deviceToken = '—';
    try {
      String? token;
      if (Platform.isIOS) {
        token = await FirebaseMessaging.instance.getAPNSToken();
      } else {
        token = await FirebaseMessaging.instance.getToken();
      }
      if (token != null && token.isNotEmpty) {
        deviceToken = token;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _environment = env;
      _bundleId = bundleId;
      _deviceToken = deviceToken;
    });
  }

  Widget _buildDebugInfoSection(bool isDarkMode) {
    final mutedColor =
        (isDarkMode ? Colors.white : Colors.black).withValues(alpha: 0.5);
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: mutedColor,
          fontSize: 11,
          fontFamily: 'monospace',
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (kDebugMode) ...[
            Text('Environment: $_environment', style: style),
            Text('Bundle ID: $_bundleId', style: style),
          ],
          if (kDebugMode && Platform.isIOS)
            Text('APNs cert: ${ChatConfig.apnsCertName}', style: style),
          if (kDebugMode)
            SelectableText(
              '${Platform.isIOS ? 'APNs' : 'FCM'} token: $_deviceToken',
              style: style,
            ),
        ],
      ),
    );
  }

  void _checkCachedSession() {
    final hasCached = SharedPrefs().routineLog.isNotEmpty;
    if (hasCached != _hasCachedSession) {
      // Defer setState to avoid calling it during build phase
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _hasCachedSession = hasCached;
          });
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _getAppVersion();
    _hasCachedSession = SharedPrefs().routineLog.isNotEmpty;
    SharedPrefs().routineLogRevision.addListener(_checkCachedSession);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _nutritionInitialized) return;
      _nutritionInitialized = true;
      context.read<NutritionLogController>().initialize();
    });
  }

  @override
  void dispose() {
    SharedPrefs().routineLogRevision.removeListener(_checkCachedSession);
    super.dispose();
  }

  void _showLogsForDate(BuildContext context, DateTime date) {
    final controller = context.read<SupabaseExerciseAndRoutineController>();
    final logs = controller.whereLogsIsSameDay(dateTime: date).toList();
    final hasLogs = logs.isNotEmpty;
    final isClientMode =
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
    final predictedDates = TrainingPredictionService.getPredictedTrainingDates(
      historicDateTimes: historicDates,
      daysAhead: daysAhead,
    );
    // Check if this is a predicted training day (today or future, no existing log)
    final selectedDateNormalized =
        DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
    final isPredicted = (isToday || isFuture) &&
        predictedDates.contains(selectedDateNormalized) &&
        !hasLogs;

    String dateLabel;
    if (isToday) {
      dateLabel = 'today';
    } else if (selectedDate == yesterday) {
      dateLabel = 'yesterday';
    } else {
      dateLabel = DateFormat('EEEE').format(date).toLowerCase();
    }

    showCalendarDateLogsSheet(
      context: context,
      date: date,
      logs: logs,
      dateLabel: dateLabel,
      isToday: isToday,
      isPredicted: isPredicted,
      showLogWorkoutButton: !isClientMode,
    );
  }
}

class _TrainingInsightsSection extends StatelessWidget {
  final _YearTrainingStats yearStats;
  final _YearHoursStats yearHoursStats;
  final _PredictionInfo predictionInfo;

  const _TrainingInsightsSection({
    required this.yearStats,
    required this.yearHoursStats,
    required this.predictionInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final cardWidth = screenWidth * 0.90; // 90% of screen width for each card
    final cardSpacing = 16.0;

    final percentLabel =
        (yearStats.progress * 100).clamp(0, 100).toStringAsFixed(0);
    final predictedHoursLeft =
        (yearHoursStats.totalProjectedHours - yearHoursStats.loggedHours)
            .clamp(0.0, double.infinity);

    // Check if today is predicted (date is today and daysUntilNext is 0)
    final hasTodayPrediction =
        predictionInfo.date != null && predictionInfo.daysUntilNext == 0;
    final hasNextPrediction =
        predictionInfo.date != null && predictionInfo.daysUntilNext != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        // Edge-to-edge horizontal scroll view for progress cards
        SizedBox(
          height: 200,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            children: [
              // Progress this year card
              SizedBox(
                width: cardWidth,
                child: _FrostedCard(
                  gradientColors: [
                    theme.colors.vibrantAccent.withValues(alpha: 0.3),
                    const Color(0xFF22c55e).withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.5),
                  ],
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row with title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'progress this year',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Large percentage display
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '$percentLabel%',
                            style: theme.textTheme.displayLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                ) ??
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Segmented horizontal bar
                      _SegmentedProgressBar(
                        loggedSessions: yearStats.daysTrained,
                        totalSessions: yearStats.totalProjectedSessions,
                        accentColor: theme.colors.vibrantAccent,
                      ),
                      const SizedBox(height: 12),
                      // Legend
                      Row(
                        children: [
                          _LegendItem(
                            color: theme.colors.vibrantAccent,
                            label: 'Logged',
                            value: yearStats.daysTrained.toString(),
                          ),
                          const SizedBox(width: 16),
                          _LegendItem(
                            color: theme.colors.vibrantAccent
                                .withValues(alpha: 0.6),
                            label: 'Predicted',
                            value: (yearStats.totalProjectedSessions -
                                    yearStats.daysTrained)
                                .toString(),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: cardSpacing),
              // Predicted total hours card
              SizedBox(
                width: cardWidth,
                child: _FrostedCard(
                  gradientColors: [
                    Colors.blue.withValues(alpha: 0.3),
                    const Color(0xFF3b82f6).withValues(alpha: 0.2),
                    Colors.black.withValues(alpha: 0.5),
                  ],
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row with title
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'hours of training',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Hours left display
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            predictedHoursLeft.round().toString(),
                            style: theme.textTheme.displayLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                ) ??
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 48,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Text(
                              'hours left',
                              style: theme.textTheme.titleMedium?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontWeight: FontWeight.w600,
                                  ) ??
                                  TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Segmented horizontal bar
                      _SegmentedProgressBar(
                        loggedSessions: yearHoursStats.loggedHours.round(),
                        totalSessions:
                            yearHoursStats.totalProjectedHours.round(),
                        accentColor: Colors.blue,
                        icon: FontAwesomeIcons.clock,
                      ),
                      const SizedBox(height: 12),
                      // Legend (hours, not days)
                      Row(
                        children: [
                          _LegendItem(
                            color: Colors.blue,
                            label: 'Logged',
                            value:
                                '${yearHoursStats.loggedHours.round()} hrs',
                          ),
                          const SizedBox(width: 16),
                          _LegendItem(
                            color: Colors.blue.withValues(alpha: 0.6),
                            label: 'Predicted',
                            value:
                                '${(yearHoursStats.totalProjectedHours - yearHoursStats.loggedHours).round()} hrs',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        // Prediction card (below the scroll view, with padding)
        if (hasTodayPrediction || hasNextPrediction) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                final availableWidth = maxWidth.isFinite
                    ? maxWidth
                    : MediaQuery.of(context).size.width - 20;
                return SizedBox(
                  width: availableWidth,
                  child: _PredictionCard(
                    predictionInfo: predictionInfo,
                    hasTodayPrediction: hasTodayPrediction,
                    hasNextPrediction: hasNextPrediction,
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _PredictionCard extends StatelessWidget {
  final _PredictionInfo predictionInfo;
  final bool hasTodayPrediction;
  final bool hasNextPrediction;

  const _PredictionCard({
    required this.predictionInfo,
    required this.hasTodayPrediction,
    required this.hasNextPrediction,
  });

  @override
  Widget build(BuildContext context) {
    Theme.of(context);

    return _NextSessionContent(
      predictionInfo: predictionInfo,
      isCompact: false,
    );
  }
}

class _NextSessionContent extends StatefulWidget {
  final _PredictionInfo predictionInfo;
  final bool isCompact;

  const _NextSessionContent({
    required this.predictionInfo,
    required this.isCompact,
  });

  @override
  State<_NextSessionContent> createState() => _NextSessionContentState();
}

class _NextSessionContentState extends State<_NextSessionContent> {
  _PredictionInfo? _currentPredictionInfo;
  DateTime? _lastLogsHash; // Track when logs change

  @override
  void initState() {
    super.initState();
    _currentPredictionInfo = widget.predictionInfo;
    _updateLogsHash();
  }

  @override
  void didUpdateWidget(_NextSessionContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset if prediction info changes
    if (oldWidget.predictionInfo.date != widget.predictionInfo.date ||
        oldWidget.predictionInfo.time != widget.predictionInfo.time) {
      _currentPredictionInfo = widget.predictionInfo;
      _updateLogsHash();
    }
  }

  void _updateLogsHash() {
    if (!mounted) return;
    final controller = context.read<SupabaseExerciseAndRoutineController>();
    // Use logs count and last log time as a simple hash to detect changes
    final logs = controller.logs;
    if (logs.isEmpty) {
      _lastLogsHash = null;
    } else {
      // Get the most recent log's start time as a hash
      _lastLogsHash = logs
          .map((log) => log.startTime)
          .reduce((a, b) => a.isAfter(b) ? a : b);
    }
  }

  void _recalculateNextSession() {
    if (!mounted) return;

    final controller = context.read<SupabaseExerciseAndRoutineController>();
    final logs = controller.logs;

    // Recalculate prediction
    final nextSession = TrainingPredictionService.getNextPredictedSession(logs);
    final newPrediction = nextSession != null
        ? _PredictionInfo(
            date: nextSession.date,
            time: nextSession.time,
            daysUntilNext: nextSession.daysUntilNext,
          )
        : const _PredictionInfo(date: null, time: null);

    setState(() {
      _currentPredictionInfo = newPrediction;
      _updateLogsHash();
    });
  }

  void _onCountdownElapsed() {
    // Silently skip the elapsed session and recalculate the next one
    // No overdue state, no negative messaging - just move forward
    _recalculateNextSession();
  }

  @override
  Widget build(BuildContext context) {
    // Listen for log changes and recalculate if needed
    final controller = context.watch<SupabaseExerciseAndRoutineController>();
    final logs = controller.logs;

    // Check if logs have changed (session logged or deleted)
    DateTime? currentLogsHash;
    if (logs.isNotEmpty) {
      currentLogsHash = logs
          .map((log) => log.startTime)
          .reduce((a, b) => a.isAfter(b) ? a : b);
    }

    if (currentLogsHash != _lastLogsHash) {
      // Logs changed - recalculate immediately
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _recalculateNextSession();
        }
      });
    }

    final predictionInfo = _currentPredictionInfo ?? widget.predictionInfo;
    final hasCountdown =
        predictionInfo.date != null && predictionInfo.time != null;

    // Calculate countdown duration dynamically (targetDateTime - now)
    // This ensures we always compute from the exact target time, not a stored duration
    Duration? countdownDuration;
    DateTime? targetDateTime;
    if (hasCountdown) {
      targetDateTime = DateTime(
        predictionInfo.date!.year,
        predictionInfo.date!.month,
        predictionInfo.date!.day,
        predictionInfo.time!.hour,
        predictionInfo.time!.minute,
      );
      final now = DateTime.now();
      final difference = targetDateTime.difference(now);

      // Only show countdown if:
      // - Target is in the future (not negative)
      // - Within 7 days
      // - Target has exact start time (not just date)
      if (!difference.isNegative && difference.inDays <= 7) {
        countdownDuration = difference;
      }
    }

    // Show empty state with positive CTA if no upcoming sessions
    if (countdownDuration == null) {
      return _buildEmptyState(context);
    }

    final theme = Theme.of(context);

    return _FrostedCard(
      gradientColors: [
        Colors.white.withValues(alpha: 0.9),
        Colors.white.withValues(alpha: 0.8),
        Colors.white.withValues(alpha: 0.7),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'next predicted session in',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.black.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          // Countdown timer - passes targetDateTime for dynamic calculation
          _FormattedCountdownTimer(
            targetDateTime: targetDateTime!,
            onElapsed: _onCountdownElapsed,
            isCompact: widget.isCompact,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final forClient = AppConfig.isClient;
    return _FrostedCard(
      gradientColors: [
        Colors.white.withValues(alpha: 0.9),
        Colors.white.withValues(alpha: 0.8),
        Colors.white.withValues(alpha: 0.7),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'plan your next session',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.black.withValues(alpha: 0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            forClient
                ? 'Start a session now'
                : 'Start a session now or create a new routine plan',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _FormattedCountdownTimer extends StatefulWidget {
  final DateTime targetDateTime;
  final VoidCallback? onElapsed;
  final bool isCompact;

  const _FormattedCountdownTimer({
    required this.targetDateTime,
    this.onElapsed,
    required this.isCompact,
  });

  @override
  State<_FormattedCountdownTimer> createState() =>
      _FormattedCountdownTimerState();
}

class _FormattedCountdownTimerState extends State<_FormattedCountdownTimer> {
  late Timer _timer;
  bool _hasElapsed = false;

  @override
  void initState() {
    super.initState();

    // Fire a timer every second to recalculate remaining duration
    // Always compute: targetDateTime - now (not decrementing stored duration)
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        final now = DateTime.now();
        final difference = widget.targetDateTime.difference(now);

        setState(() {
          if (difference.isNegative || difference.inSeconds <= 0) {
            // Timer reached zero or target is in the past
            _timer.cancel();
            if (!_hasElapsed) {
              _hasElapsed = true;
              // Call the callback to notify parent (silently skip and recalculate)
              widget.onElapsed?.call();
            }
          }
          // Duration is computed dynamically in build(), no need to store it
        });
      }
    });
  }

  Duration get _remainingDuration {
    // Always compute dynamically: targetDateTime - now
    final now = DateTime.now();
    final difference = widget.targetDateTime.difference(now);
    // Clamp to zero if negative
    return difference.isNegative ? Duration.zero : difference;
  }

  String _twoDigits(int n) {
    // Ensure all values are displayed as exactly 2 digits
    return n < 10 ? '0$n' : n.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final days = _remainingDuration.inDays;
    final hours = _remainingDuration.inHours.remainder(24);
    final minutes = _remainingDuration.inMinutes.remainder(60);
    final seconds = _remainingDuration.inSeconds.remainder(60);

    final numberStyle = theme.textTheme.displayLarge?.copyWith(
          color: Colors.black,
          fontWeight: FontWeight.w900,
          height: 1.0,
          fontSize: widget.isCompact ? 64 : 80,
        ) ??
        TextStyle(
          color: Colors.black,
          fontSize: widget.isCompact ? 64 : 80,
          fontWeight: FontWeight.w900,
          height: 1.0,
          fontFamily: 'Grift',
        );

    final labelStyle = theme.textTheme.bodySmall?.copyWith(
          color: Colors.black.withValues(alpha: 0.6),
          fontWeight: FontWeight.w500,
        ) ??
        TextStyle(
          color: Colors.black.withValues(alpha: 0.6),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: 'Grift',
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top row: Days and Hours (labels above)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Days (top left)
            SizedBox(
              width: widget.isCompact ? 80 : 100,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'DAYS',
                    style: labelStyle,
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      _twoDigits(days),
                      style: numberStyle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: widget.isCompact ? 24 : 32),
            // Separator
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20), // Match label height
                Text(
                  ':',
                  style: numberStyle.copyWith(
                    fontSize: widget.isCompact ? 48 : 60,
                  ),
                ),
              ],
            ),
            SizedBox(width: widget.isCompact ? 24 : 32),
            // Hours (top right)
            SizedBox(
              width: widget.isCompact ? 80 : 100,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'HOURS',
                    style: labelStyle,
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      _twoDigits(hours),
                      style: numberStyle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: widget.isCompact ? 24 : 32),
        // Bottom row: Minutes and Seconds (labels below)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Minutes (bottom left)
            SizedBox(
              width: widget.isCompact ? 80 : 100,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      _twoDigits(minutes),
                      style: numberStyle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'MINUTES',
                    style: labelStyle,
                  ),
                ],
              ),
            ),
            SizedBox(width: widget.isCompact ? 24 : 32),
            // Separator
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  ':',
                  style: numberStyle.copyWith(
                    fontSize: widget.isCompact ? 48 : 60,
                  ),
                ),
                const SizedBox(height: 20), // Match label height
              ],
            ),
            SizedBox(width: widget.isCompact ? 24 : 32),
            // Seconds (bottom right)
            SizedBox(
              width: widget.isCompact ? 80 : 100,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      _twoDigits(seconds),
                      style: numberStyle,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'SECONDS',
                    style: labelStyle,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }
}

class _FrostedCard extends StatelessWidget {
  final Widget child;
  final List<Color> gradientColors;

  const _FrostedCard({
    required this.child,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Stack(
            children: [
              // Texture overlay
              Positioned.fill(
                child: Opacity(
                  opacity: 0.15,
                  child: Image.asset(
                    'images/1k_Dissolve_Noise_Texture.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              // Content
              Padding(
                padding: const EdgeInsets.all(22),
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnsavedSessionCard extends StatefulWidget {
  final VoidCallback onTap;

  const _UnsavedSessionCard({required this.onTap});

  @override
  State<_UnsavedSessionCard> createState() => _UnsavedSessionCardState();
}

class _UnsavedSessionCardState extends State<_UnsavedSessionCard> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  RoutineLogDto? _routineLog;

  @override
  void initState() {
    super.initState();
    _loadCachedLog();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _loadCachedLog() {
    final cache = SharedPrefs().routineLog;
    if (cache.isNotEmpty) {
      try {
        final json = jsonDecode(cache);
        setState(() {
          _routineLog = RoutineLogDto.fromJson(json: json);
        });
        _startTimer();
      } catch (e) {
        debugPrint('Error loading cached routine log: $e');
      }
    }
  }

  void _startTimer() {
    if (_routineLog == null) return;

    _elapsed = DateTime.now().difference(_routineLog!.startTime);
    if (_elapsed.isNegative) {
      _elapsed = Duration.zero;
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;

      // Reload cached log to get latest checked sets
      final cache = SharedPrefs().routineLog;
      if (cache.isNotEmpty) {
        try {
          final json = jsonDecode(cache);
          final updatedLog = RoutineLogDto.fromJson(json: json);
          setState(() {
            _routineLog = updatedLog;
            _elapsed = DateTime.now().difference(_routineLog!.startTime);
            if (_elapsed.isNegative) {
              _elapsed = Duration.zero;
            }
          });
        } catch (e) {
          debugPrint('Error reloading cached routine log: $e');
        }
      }
    });
  }

  String _formatElapsedDuration(Duration duration) {
    return duration.inHours >= 1 ? duration.hmsDigital() : duration.msDigital();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String workoutName = 'Unsaved Workout';
    String exerciseCount = '0 exercises';

    if (_routineLog != null) {
      workoutName = _routineLog!.name;
      exerciseCount =
          '${_routineLog!.exerciseLogs.length} ${_routineLog!.exerciseLogs.length == 1 ? 'exercise' : 'exercises'}';
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: _FrostedCard(
        gradientColors: [
          const Color(0xFFf59e0b).withValues(alpha: 0.3),
          const Color(0xFFfbbf24).withValues(alpha: 0.2),
          Colors.black.withValues(alpha: 0.5),
        ],
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              color: Colors.white.withValues(alpha: 0.9),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unsaved Workout',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    workoutName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white70,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    exerciseCount,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              _formatElapsedDuration(_elapsed),
              style: theme.textTheme.headlineSmall?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PredictionInfo {
  final DateTime? date;
  final TimeOfDay? time;
  final int? daysUntilNext;

  const _PredictionInfo({
    required this.date,
    required this.time,
    this.daysUntilNext,
  });

  // This method is no longer used - replaced by TrainingPredictionService.getNextPredictedSession
  // Kept for backward compatibility with _PredictionInfo structure
}

class _YearTrainingStats {
  final int year;
  final int daysTrained;
  final int totalProjectedSessions;
  final double progress;

  const _YearTrainingStats({
    required this.year,
    required this.daysTrained,
    required this.totalProjectedSessions,
    required this.progress,
  });

  static _YearTrainingStats fromLogs(List<RoutineLogDto> logs) {
    final now = DateTime.now();
    final currentYear = now.year;
    final todayStart = DateTime(now.year, now.month, now.day);
    final yearDays = logs
        .where((log) => log.startTime.year == currentYear)
        .map((log) => DateTime(
            log.startTime.year, log.startTime.month, log.startTime.day))
        .toSet()
        .length;

    final endOfYear = DateTime(currentYear, 12, 31);
    final daysAhead = endOfYear.difference(todayStart).inDays;
    int predictedRemaining = 0;
    if (daysAhead > 0 && logs.isNotEmpty) {
      final predictedSet = getPredictedTrainingDates(
        historicDateTimes: logs.map((log) => log.startTime).toList(),
        daysAhead: daysAhead,
      );
      predictedRemaining =
          predictedSet.where((date) => !date.isBefore(todayStart)).length;
    }

    final totalProjectedSessions = yearDays + predictedRemaining;
    final progress = totalProjectedSessions == 0
        ? 0.0
        : (yearDays / totalProjectedSessions).clamp(0, 1).toDouble();

    return _YearTrainingStats(
      year: currentYear,
      daysTrained: yearDays,
      totalProjectedSessions: totalProjectedSessions,
      progress: progress,
    );
  }
}

class _YearHoursStats {
  final int year;
  final double loggedHours;
  final double totalProjectedHours;
  final double progress;

  const _YearHoursStats({
    required this.year,
    required this.loggedHours,
    required this.totalProjectedHours,
    required this.progress,
  });

  static _YearHoursStats fromLogs(List<RoutineLogDto> logs) {
    final now = DateTime.now();
    final currentYear = now.year;
    final todayStart = DateTime(now.year, now.month, now.day);

    // Calculate logged hours for current year
    final loggedHours = logs
        .where((log) => log.startTime.year == currentYear)
        .map((log) => log.duration().inSeconds / 3600.0)
        .fold<double>(0.0, (sum, hours) => sum + hours);

    // Calculate predicted remaining hours: average duration × number of predicted days
    // Create a set of dates that already have logs (normalized to day level)
    final loggedDates = logs.map((log) {
      final date = log.startTime;
      return DateTime(date.year, date.month, date.day);
    }).toSet();

    double predictedRemainingHours = 0.0;
    if (logs.isNotEmpty) {
      // Calculate average training duration from all logs
      final avgDurationHours = logs
              .map((log) => log.duration().inSeconds / 3600.0)
              .fold<double>(0.0, (sum, hours) => sum + hours) /
          logs.length;

      final endOfYear = DateTime(currentYear, 12, 31);
      final daysAhead = endOfYear.difference(todayStart).inDays;

      if (daysAhead > 0) {
        final predictedSet = getPredictedTrainingDates(
          historicDateTimes: logs.map((log) => log.startTime).toList(),
          daysAhead: daysAhead,
        );

        // Filter out predicted dates that already have logs, and only count from today onwards
        final predictedDatesWithoutLogs = predictedSet
            .where((date) =>
                !date.isBefore(todayStart) && !loggedDates.contains(date))
            .toList();

        // Multiply average duration by number of predicted training days
        final numberOfPredictedDays = predictedDatesWithoutLogs.length;
        predictedRemainingHours = avgDurationHours * numberOfPredictedDays;
      }
    }
    final totalProjectedHours = loggedHours + predictedRemainingHours;
    final progress = totalProjectedHours == 0
        ? 0.0
        : (loggedHours / totalProjectedHours).clamp(0, 1).toDouble();

    return _YearHoursStats(
      year: currentYear,
      loggedHours: loggedHours,
      totalProjectedHours: totalProjectedHours,
      progress: progress,
    );
  }
}

class _SegmentedProgressBar extends StatefulWidget {
  final int loggedSessions;
  final int totalSessions;
  final Color accentColor;
  final IconData? icon;

  const _SegmentedProgressBar({
    required this.loggedSessions,
    required this.totalSessions,
    required this.accentColor,
    this.icon,
  });

  @override
  State<_SegmentedProgressBar> createState() => _SegmentedProgressBarState();
}

class _SegmentedProgressBarState extends State<_SegmentedProgressBar> {
  @override
  Widget build(BuildContext context) {
    if (widget.totalSessions == 0) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = constraints.maxWidth;
          final iconSize = 24.0;
          final iconOffset = iconSize / 2;

          return Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  bottomLeft: Radius.circular(6),
                ),
                child: Container(
                  height: 12,
                  width: barWidth,
                  decoration: BoxDecoration(
                    color: widget.accentColor.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(6),
                      bottomLeft: Radius.circular(6),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -iconOffset,
                child: Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: const BoxDecoration(
                    color: Color(0xFF3A3A3A),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: FaIcon(
                      widget.icon ?? FontAwesomeIcons.star,
                      size: 14,
                      color: widget.accentColor,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }

    // Simple: show logged portion of total sessions
    final maxValue = widget.totalSessions > 0 ? widget.totalSessions : 1;
    final loggedRatio = (widget.loggedSessions / maxValue).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final barWidth = constraints.maxWidth;
        final loggedWidth = barWidth * loggedRatio;
        final iconSize = 24.0;
        final iconOffset = iconSize / 2;

        return Stack(
          alignment: Alignment.centerLeft,
          clipBehavior: Clip.none,
          children: [
            // Bar content with rounded corners on left
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                bottomLeft: Radius.circular(6),
              ),
              child: Stack(
                alignment: Alignment.centerLeft,
                clipBehavior: Clip.none,
                children: [
                  // Background track (predicted - darker accent color)
                  Container(
                    height: 12,
                    width: barWidth,
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.3),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        bottomLeft: Radius.circular(6),
                      ),
                    ),
                  ),
                  // Logged sessions (accent color) - overlays on top of predicted
                  if (loggedWidth > 0)
                    Container(
                      height: 12,
                      width: loggedWidth,
                      decoration: BoxDecoration(
                        color: widget.accentColor,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          bottomLeft: Radius.circular(6),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Medal icon at the far right end (outside ClipRRect so it's not clipped)
            Positioned(
              right: -iconOffset,
              child: Container(
                width: iconSize,
                height: iconSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF3A3A3A), // Slightly darker gray circle
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: FaIcon(
                    widget.icon ?? FontAwesomeIcons.star,
                    size: 14,
                    color: widget.accentColor,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final String? value;

  const _LegendItem({
    required this.color,
    required this.label,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          value != null ? '$label $value' : label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                fontSize: 12,
              ),
        ),
      ],
    );
  }
}

// --- Nutrition section (mirrors routine plans) ---

class _NutritionSection extends StatelessWidget {
  const _NutritionSection();

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static double _sumCaloriesToday(List<NutritionLogDto> logs) {
    final now = DateTime.now();
    final todayLogs =
        logs.where((log) => _isSameDay(log.loggedAt.toLocal(), now));
    return todayLogs.fold(0.0, (sum, log) => sum + log.calories);
  }

  static bool _hasLogsToday(List<NutritionLogDto> logs) {
    final now = DateTime.now();
    return logs.any((log) => _isSameDay(log.loggedAt.toLocal(), now));
  }

  static double _sumProteinToday(List<NutritionLogDto> logs) {
    final now = DateTime.now();
    final todayLogs =
        logs.where((log) => _isSameDay(log.loggedAt.toLocal(), now));
    return todayLogs.fold(0.0, (sum, log) => sum + log.protein);
  }

  static double _sumCarbsToday(List<NutritionLogDto> logs) {
    final now = DateTime.now();
    final todayLogs =
        logs.where((log) => _isSameDay(log.loggedAt.toLocal(), now));
    return todayLogs.fold(0.0, (sum, log) => sum + log.carbs);
  }

  static double _sumFatsToday(List<NutritionLogDto> logs) {
    final now = DateTime.now();
    final todayLogs =
        logs.where((log) => _isSameDay(log.loggedAt.toLocal(), now));
    return todayLogs.fold(0.0, (sum, log) => sum + log.fats);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ClientSubscriptionService.instance.accessRevision,
      builder: (context, _) {
        final showSubscribe =
            AppConfig.isClient && !ClientSubscriptionService.instance.hasAccess;

        return Consumer<NutritionLogController>(
          builder: (context, nutritionController, _) {
            final canEditNutrition = AppPrivileges.isCoach;
            final template = nutritionController.nutritionTemplate;

            Widget subscribeBlock() => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: ClientSubscribePromptCard(
                    onSubscribe: (assignedCoach) {
                      ClientSubscriptionService.instance.showPaywall(
                        context: context,
                        assignedCoach: assignedCoach,
                      );
                    },
                  ),
                );

            // Client, no template: only show subscribe prompt when applicable
            if (!canEditNutrition && template == null) {
              if (!showSubscribe) return const SizedBox.shrink();
              return subscribeBlock();
            }

            if (canEditNutrition && template == null) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                child: const _NutritionCreateRow(),
              );
            }

            final consumedCalories = _sumCaloriesToday(nutritionController.logs);
            final goalCalories = nutritionController.calorieTarget;
            final hasLogsToday = _hasLogsToday(nutritionController.logs);
            final remainingCalories = goalCalories > 0
                ? (hasLogsToday
                    ? (goalCalories - consumedCalories).clamp(0.0, goalCalories)
                    : goalCalories)
                : 0.0;

            final carousel = NutritionTrackingCarousel(
              goalCalories: goalCalories,
              remainingCalories: remainingCalories,
              proteinTarget: nutritionController.proteinTarget,
              carbsTarget: nutritionController.carbsTarget,
              fatsTarget: nutritionController.fatsTarget,
              consumedProtein: _sumProteinToday(nutritionController.logs),
              consumedCarbs: _sumCarbsToday(nutritionController.logs),
              consumedFats: _sumFatsToday(nutritionController.logs),
              hasLogsToday: hasLogsToday,
              useSingleStack: true,
              calorieCardHeroTag: 'nutrition_calorie_card',
              onCardTap: () {
                if (canEditNutrition && nutritionController.logs.isEmpty) {
                  showNutritionTemplateSheet(context);
                  return;
                }
                Navigator.of(context).push(
                  PageRouteBuilder(
                    pageBuilder: (_, __, ___) => const NutritionTrackerScreen(),
                    transitionsBuilder: (_, animation, __, child) {
                      final tween = Tween(
                        begin: const Offset(0, 1),
                        end: Offset.zero,
                      ).chain(CurveTween(curve: Curves.easeOutCubic));
                      return SlideTransition(
                        position: animation.drive(tween),
                        child: child,
                      );
                    },
                  ),
                );
              },
            );

            if (!showSubscribe) return carousel;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                subscribeBlock(),
                const SizedBox(height: 16),
                carousel,
              ],
            );
          },
        );
      },
    );
  }
}

/// Coach: empty state with CTA to create nutrition template for selected client.
class _NutritionCreateRow extends StatelessWidget {
  const _NutritionCreateRow();

  @override
  Widget build(BuildContext context) {
    return _CreateSectionFrostedCard(
      title: 'Nutrition',
      description:
          'Create a nutrition template to set macro targets for this client.',
      ctaLabel: 'Create nutrition template',
      onPressed: () => showNutritionTemplateSheet(context),
      gradientColors: [
        Colors.green.withValues(alpha: 0.3),
        Colors.teal.withValues(alpha: 0.24),
        Colors.black.withValues(alpha: 0.45),
      ],
    );
  }
}

// This function is no longer used - replaced by TrainingPredictionService.deriveTypicalTimeForWeekday

/// Spacer after nutrition - only when that section rendered content.
/// Avoids double gap when client has no template (section shrinks).
class _SpacerIfNutritionVisible extends StatelessWidget {
  const _SpacerIfNutritionVisible();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ClientSubscriptionService.instance.accessRevision,
      builder: (context, _) {
        final showSubscribe =
            AppConfig.isClient && !ClientSubscriptionService.instance.hasAccess;
        return Consumer<NutritionLogController>(
          builder: (context, controller, _) {
            final hasContent = AppPrivileges.isCoach ||
                controller.nutritionTemplate != null ||
                showSubscribe;
            return hasContent
                ? SizedBox(height: _SettingsScreenState._sectionSpacing)
                : const SizedBox.shrink();
          },
        );
      },
    );
  }
}

class _CreateSectionFrostedCard extends StatelessWidget {
  final String title;
  final String description;
  final String ctaLabel;
  final VoidCallback onPressed;
  final List<Color> gradientColors;

  const _CreateSectionFrostedCard({
    required this.title,
    required this.description,
    required this.ctaLabel,
    required this.onPressed,
    required this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return FrostedCard(
      gradientColors: gradientColors,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: OpacityButtonWidgetTwo(
              onPressed: onPressed,
              label: ctaLabel,
            ),
          ),
        ],
      ),
    );
  }
}
