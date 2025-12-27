import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/screens/request_screens/notifications_request.dart';
import 'package:trainware/shared_prefs.dart';
import 'package:trainware/urls.dart';

import '../../controllers/supabase_exercise_and_routine_controller.dart';
import '../../dtos/appsync/routine_log_dto.dart';
import '../../dtos/appsync/routine_plan_dto.dart';
import '../../dtos/viewmodels/routine_plan_arguments.dart';
import '../../dtos/viewmodels/past_routine_log_arguments.dart';
import '../../dtos/routine_timeline_event_dto.dart';
import '../../extensions/duration_extension.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/general_utils.dart';
import '../../utils/notifications_utils.dart';
import '../../utils/navigation_utils.dart';
import '../../utils/uri_utils.dart';
import '../../utils/unsaved_workout_utils.dart';
import '../../widgets/backgrounds/trkr_loading_screen.dart';
import '../../widgets/buttons/opacity_button_widget_two.dart';
import '../../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../../widgets/calendar/calendar.dart';
import '../../widgets/dividers/label_divider.dart';
import '../../widgets/information_containers/information_container_with_background_image.dart';
import '../../widgets/routine/preview/routine_plan_grid_item.dart';
import '../../widgets/routine/preview/routine_log_widget.dart';
import '../../screens/routines/routine_plan.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import '../../repositories/routine_timeline_repository.dart';
import '../exercise/history/latest_recap_screen.dart';

enum WeightUnit {
  kg("kg"),
  lbs("lbs");

  const WeightUnit(this.display);

  final String display;

  static WeightUnit fromString(String string) {
    return WeightUnit.values.firstWhere((value) => value.name == string);
  }
}

enum HeightUnit {
  ftIn("ft"),
  cm("cm");

  const HeightUnit(this.display);

  final String display;

  static HeightUnit fromString(String string) {
    return HeightUnit.values.firstWhere((value) => value.name == string);
  }
}

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

  late WeightUnit _weightUnit;

  String _appVersion = "";

  bool _notificationEnabled = false;
  bool _hasCachedSession = false;
  final RoutineTimelineRepository _timelineRepository =
      RoutineTimelineRepository();

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;
    final theme = Theme.of(context);

    if (_loading) return TRKRLoadingScreen(action: _hideLoadingScreen);

    final userEmail =
        Supabase.instance.client.auth.currentUser?.email ?? "User";
    final controller = context.watch<SupabaseExerciseAndRoutineController>();
    final logs = controller.logs;
    final yearStats = _YearTrainingStats.fromLogs(logs);
    final predictionInfo = _PredictionInfo.fromLogs(logs);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
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
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: _UnsavedSessionCard(
                        onTap: () => showUnsavedWorkoutBottomSheet(context),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: _buildRecapCard(theme),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: _TrainingInsightsSection(
                      yearStats: yearStats,
                      predictionInfo: predictionInfo,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Routine Plans section - edge-to-edge, no padding
                  _RoutinePlansSection(),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: InformationContainerWithBackgroundImage(
                      image: 'images/background.jpg',
                      subtitle:
                          "Loving the app? Learn more about us and our mission.",
                      color: Colors.black,
                      onTap: _openWebpage,
                      alignmentGeometry: Alignment.center,
                    ),
                  ),
                  const SizedBox(
                    height: 20,
                  ),
                  if (Platform.isIOS)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LabelDivider(
                                label: "Notifications",
                                labelColor:
                                    isDarkMode ? Colors.white : Colors.black,
                                dividerColor:
                                    Theme.of(context).colors.dividerColor,
                                fontSize: 14,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                "Allow us to remind you about long-running workouts if you’ve become distracted. We’ll also send reminders on your training days.",
                                textAlign: TextAlign.start,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w400,
                                      color: isDarkMode
                                          ? Colors.white70
                                          : Colors.black,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color:
                                      (isDarkMode ? Colors.white : Colors.black)
                                          .withValues(
                                              alpha: isDarkMode ? 0.06 : 0.05),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Theme.of(context)
                                        .colors
                                        .borderLight
                                        .withValues(alpha: 0.1),
                                  ),
                                ),
                                child: ListTile(
                                  onTap: _turnOnNotification,
                                  dense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  tileColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  title: Text(
                                    _notificationEnabled
                                        ? "Notification is on"
                                        : "Turn on notifications",
                                    textAlign: TextAlign.start,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                        ),
                                  ),
                                  trailing: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color:
                                          Theme.of(context).colors.glassLight,
                                      shape: BoxShape.circle,
                                    ),
                                    child: FaIcon(
                                      FontAwesomeIcons.solidBell,
                                      size: 14,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 30.0),
                    tileColor: Colors.transparent,
                    title: Text("Weight",
                        style: Theme.of(context).textTheme.titleMedium),
                    subtitle: const Text("Choose kg or lbs"),
                    trailing: CupertinoSlidingSegmentedControl<WeightUnit>(
                      backgroundColor: isDarkMode
                          ? Theme.of(context).colors.sapphireDark
                          : Colors.grey.shade400,
                      thumbColor: isDarkMode
                          ? Theme.of(context).colors.sapphireDark80
                          : Colors.white,
                      groupValue: _weightUnit,
                      children: {
                        WeightUnit.kg: SizedBox(
                            width: 30,
                            child: Text(WeightUnit.kg.display,
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center)),
                        WeightUnit.lbs: SizedBox(
                            width: 30,
                            child: Text(WeightUnit.lbs.display,
                                style: Theme.of(context).textTheme.bodySmall,
                                textAlign: TextAlign.center)),
                      },
                      onValueChanged: (WeightUnit? value) {
                        if (value != null) {
                          setState(() {
                            _weightUnit = value;
                          });
                          toggleWeightUnit(unit: value);
                        }
                      },
                    ),
                  ),
                  ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 30.0),
                      onTap: _showAccountOptionsBottomSheet,
                      leading: FaIcon(FontAwesomeIcons.user,
                          color: isDarkMode ? Colors.white70 : Colors.black38),
                      title: Text("Account",
                          style: Theme.of(context).textTheme.titleMedium),
                      subtitle: Text(userEmail)),
                  Center(
                    child: Text(
                      _appVersion,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  void _openWebpage() {
    final url = trackrWebUrl;
    openUrl(url: url, context: context);
  }

  _RecapStats _recapStats(List<RoutineTimelineEventDto> events) {
    final exerciseNames = <String>{};
    int setsCompleted = 0;
    for (final e in events) {
      if (e.exerciseName != null) exerciseNames.add(e.exerciseName!);
      if (e.action == 'check_set' && (e.checked ?? false)) {
        setsCompleted++;
      }
    }
    return _RecapStats(
      uniqueExercises: exerciseNames.length,
      setsCompleted: setsCompleted,
    );
  }

  Widget _buildRecapCard(ThemeData theme) {
    return FutureBuilder<(String?, List<RoutineTimelineEventDto>)>(
      future: _timelineRepository.loadLatest(),
      builder: (context, snapshot) {
        final events = snapshot.data?.$2 ?? const [];
        final logId = snapshot.data?.$1;
        final stats = _recapStats(events);
        final hasData = events.isNotEmpty;
        return _FrostedCard(
          gradientColors: [
            const Color(0xFF22c55e).withValues(alpha: 0.25),
            Colors.black.withValues(alpha: 0.4),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 12,
            children: [
              Text(
                'latest recap',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                hasData
                    ? '${stats.setsCompleted} sets • ${stats.uniqueExercises} exercises'
                    : 'No recap captured yet',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ),
              OpacityButtonWidgetTwo(
                solidBackground: true,
                showArrowRight: false,
                label: hasData ? 'Open recap' : 'Nothing to show',
                buttonColor: Colors.green.shade700,
                onPressed: hasData
                    ? () {
                        showAppBottomSheet(
                          context: context,
                          isDraggable: true,
                          isScrollControlled: true,
                          minChildSize: 0.4,
                          initialChildSize: 0.8,
                          maxChildSize: 0.95,
                          useBlurredTransparentBackground: false,
                          builder: (ctx, scrollController) => LatestRecapScreen(
                            events: events,
                            logId: logId,
                            asSheet: true,
                            scrollController: scrollController,
                          ),
                        );
                      }
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }

  void _clearAppData() async {
    Posthog().reset();
    SharedPrefs().clear();
    await FlutterLocalNotificationsPlugin().cancelAll();
    if (mounted) {
      Provider.of<SupabaseExerciseAndRoutineController>(context, listen: false)
          .clear();
    }
  }

  void _turnOnNotification() async {
    if (!_notificationEnabled) {
      await navigateWithSlideTransition(
          context: context,
          child: NotificationsRequestScreen(onRequest: () {
            requestNotificationPermission().then((status) {
              setState(() {
                _notificationEnabled = status;
              });
              if (mounted) {
                context.pop();
              }
            });
          }));
    }
  }

  void _checkNotificationPermission() async {
    final result = await checkIosNotificationPermission();
    setState(() {
      _notificationEnabled = result.isEnabled;
    });
  }

  void _showAccountOptionsBottomSheet() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final userEmail =
        Supabase.instance.client.auth.currentUser?.email ?? "User";
    showAppBottomSheet(
      context: context,
      isScrollControlled: false,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: FaIcon(
                FontAwesomeIcons.arrowRightFromBracket,
                size: 18,
                color: isDarkMode ? Colors.white70 : Colors.black38,
              ),
              horizontalTitleGap: 10,
              title:
                  Text("Logout", style: Theme.of(context).textTheme.bodyLarge),
              subtitle: Text(userEmail),
              onTap: () {
                Navigator.of(context).pop();
                _logout();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: FaIcon(
                FontAwesomeIcons.solidCircleXmark,
                size: 18,
                color: isDarkMode ? Colors.white70 : Colors.black38,
              ),
              horizontalTitleGap: 10,
              title: Text("Delete Account",
                  style: Theme.of(context).textTheme.bodyLarge),
              subtitle: Text(userEmail),
              onTap: () {
                Navigator.of(context).pop();
                _delete();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _logout() async {
    showBottomSheetWithMultiActions(
        context: context,
        title: "Log out?",
        description: "Are you sure you want to log out?",
        leftAction: Navigator.of(context).pop,
        rightAction: () async {
          Navigator.of(context).pop();
          _showLoadingScreen();
          _clearAppData();
          await Supabase.instance.client.auth.signOut();
          if (mounted) {
            context.go('/'); // Navigate to auth screen
          }
        },
        leftActionLabel: 'Cancel',
        rightActionLabel: 'Logout',
        isRightActionDestructive: true);
  }

  void _delete() async {
    showBottomSheetWithMultiActions(
        context: context,
        title: "Delete account?",
        description:
            "Are you sure you want to delete your account? This action cannot be undone.",
        leftAction: Navigator.of(context).pop,
        rightAction: () async {
          Navigator.of(context).pop();
          _showLoadingScreen();

          try {
            final userId = Supabase.instance.client.auth.currentUser?.id;
            if (userId == null) {
              throw Exception('User not authenticated');
            }

            // Delete all user data from Supabase
            await Supabase.instance.client
                .from('exercises')
                .delete()
                .eq('owner', userId);
            await Supabase.instance.client
                .from('routine_templates')
                .delete()
                .eq('owner', userId);
            await Supabase.instance.client
                .from('routine_plans')
                .delete()
                .eq('owner', userId);
            await Supabase.instance.client
                .from('routine_logs')
                .delete()
                .eq('owner', userId);

            _hideLoadingScreen();
            _clearAppData();

            // Sign out the user (Supabase doesn't have deleteUser on client,
            // user deletion should be done via dashboard or admin API)
            await Supabase.instance.client.auth.signOut();

            if (mounted) {
              context.go('/'); // Navigate to auth screen
            }
          } catch (e) {
            _hideLoadingScreen();
            if (mounted) {
              showSnackbar(
                  context: context,
                  message: "Something went wrong. Please try again.");
            }
          }
        },
        leftActionLabel: 'Cancel',
        rightActionLabel: 'Delete',
        isRightActionDestructive: true);
  }

  void _getAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version;
    final buildNumber = packageInfo.buildNumber;
    setState(() {
      _appVersion = "APP VERSION: $version (BUILD $buildNumber)";
    });
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
    WidgetsBinding.instance.addObserver(this);
    _weightUnit = WeightUnit.fromString(SharedPrefs().weightUnit);
    _getAppVersion();
    _checkNotificationPermission();
    _hasCachedSession = SharedPrefs().routineLog.isNotEmpty;
    SharedPrefs().routineLogRevision.addListener(_checkCachedSession);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SharedPrefs().routineLogRevision.removeListener(_checkCachedSession);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    /// Uncomment this to enable notifications
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkNotificationPermission();
      });
    }
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
    final todayStart = DateTime(now.year, now.month, now.day);
    final endOfYear = DateTime(now.year, 12, 31);
    final daysAhead = endOfYear.difference(todayStart).inDays;
    final predictedDates = getPredictedTrainingDates(
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
                              Navigator.pop(sheetContext);
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
}

class _TrainingInsightsSection extends StatelessWidget {
  final _YearTrainingStats yearStats;
  final _PredictionInfo predictionInfo;

  const _TrainingInsightsSection({
    required this.yearStats,
    required this.predictionInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final dateLabel = predictionInfo.date != null
        ? _formatRelativeDate(predictionInfo.date!)
        : 'Need more workouts logged';
    final timeLabel = predictionInfo.time != null
        ? 'around ${_formatTime(predictionInfo.time!)}'
        : 'Log a few sessions to learn your timing';
    final percentLabel =
        (yearStats.progress * 100).clamp(0, 100).toStringAsFixed(0);

    final hasTodayPrediction = predictionInfo.todayDate != null;
    final hasNextPrediction =
        predictionInfo.date != null && predictionInfo.daysUntilNext != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
            final availableWidth = maxWidth.isFinite
                ? maxWidth
                : MediaQuery.of(context).size.width - 20;
            final isWide = availableWidth >= 600;
            final cardWidth =
                isWide ? (availableWidth - 16) / 2 : availableWidth;

            return Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: cardWidth,
                  child: _FrostedCard(
                    gradientColors: [
                      theme.colors.vibrantAccent.withValues(alpha: 0.3),
                      const Color(0xFF22c55e).withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.5),
                    ],
                    child: Column(
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
                        const SizedBox(height: 16),
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
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${yearStats.daysTrained}/${yearStats.totalProjectedSessions}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Segmented horizontal bar
                        _SegmentedProgressBar(
                          loggedSessions: yearStats.daysTrained,
                          predictedRemaining: yearStats.predictedRemaining,
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
                            ),
                            const SizedBox(width: 16),
                            _LegendItem(
                              color: theme.colors.vibrantAccent
                                  .withValues(alpha: 0.6),
                              label: 'Predicted',
                            ),
                            if (yearStats.totalProjectedSessions >
                                yearStats.daysTrained +
                                    yearStats.predictedRemaining) ...[
                              const SizedBox(width: 16),
                              _LegendItem(
                                color: Colors.white.withValues(alpha: 0.2),
                                label: 'Remaining',
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _PredictionCard(
                    predictionInfo: predictionInfo,
                    hasTodayPrediction: hasTodayPrediction,
                    hasNextPrediction: hasNextPrediction,
                    dateLabel: dateLabel,
                    timeLabel: timeLabel,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _PredictionCard extends StatelessWidget {
  final _PredictionInfo predictionInfo;
  final bool hasTodayPrediction;
  final bool hasNextPrediction;
  final String dateLabel;
  final String timeLabel;

  const _PredictionCard({
    required this.predictionInfo,
    required this.hasTodayPrediction,
    required this.hasNextPrediction,
    required this.dateLabel,
    required this.timeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF3b82f6).withValues(alpha: 0.3),
                const Color(0xFF60a5fa).withValues(alpha: 0.2),
                Colors.black.withValues(alpha: 0.5),
              ],
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
              // Content with proper structure for edge-to-edge divider
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top section with padding
                  Padding(
                    padding: const EdgeInsets.all(22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          hasTodayPrediction
                              ? 'today is the day to train'
                              : 'next predicted session',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Today's prediction section
                        if (hasTodayPrediction) ...[
                          Text(
                            'today',
                            style: theme.textTheme.displayMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                ) ??
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            predictionInfo.todayTime != null
                                ? 'around ${_formatTime(predictionInfo.todayTime!)}'
                                : 'Time to train',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ] else ...[
                          // Next predicted session (no today prediction)
                          Text(
                            dateLabel,
                            style: theme.textTheme.displayMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                ) ??
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                ),
                          ),
                          const SizedBox(height: 4),
                          if (timeLabel !=
                              'Log a few sessions to learn your timing') ...[
                            Text(
                              timeLabel,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  // Edge-to-edge divider (only if today is predicted and next exists)
                  if (hasTodayPrediction && hasNextPrediction)
                    Container(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.2),
                    ),
                  // Bottom section with padding (only if today is predicted and next exists)
                  if (hasTodayPrediction && hasNextPrediction)
                    Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'next predicted session',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: Colors.white.withValues(alpha: 0.7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            dateLabel,
                            style: theme.textTheme.headlineMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                ) ??
                                const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w700,
                                  height: 1.0,
                                ),
                          ),
                          const SizedBox(height: 4),
                          if (timeLabel !=
                              'Log a few sessions to learn your timing') ...[
                            const SizedBox(height: 2),
                            Text(
                              timeLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecapStats {
  final int uniqueExercises;
  final int setsCompleted;

  const _RecapStats({
    required this.uniqueExercises,
    required this.setsCompleted,
  });
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
  final DateTime? todayDate;
  final TimeOfDay? todayTime;
  final int? daysUntilNext;

  const _PredictionInfo({
    required this.date,
    required this.time,
    this.todayDate,
    this.todayTime,
    this.daysUntilNext,
  });

  static _PredictionInfo fromLogs(List<RoutineLogDto> logs) {
    if (logs.isEmpty) {
      return const _PredictionInfo(date: null, time: null);
    }

    // Create a set of dates that already have logs (normalized to day level)
    final loggedDates = logs.map((log) {
      final date = log.startTime;
      return DateTime(date.year, date.month, date.day);
    }).toSet();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final endOfYear = DateTime(now.year, 12, 31);
    final daysAhead = endOfYear.difference(todayStart).inDays;
    final predictedSet = getPredictedTrainingDates(
      historicDateTimes: logs.map((log) => log.startTime).toList(),
      daysAhead: daysAhead,
    );

    // Filter out predicted dates that already have logs
    final predictedDaysWithoutLogs = predictedSet
        .where((date) => !loggedDates.contains(date))
        .toList()
      ..sort((a, b) => a.compareTo(b));

    if (predictedDaysWithoutLogs.isEmpty) {
      return const _PredictionInfo(date: null, time: null);
    }

    final startOfToday = DateTime(now.year, now.month, now.day);

    // Check if today is predicted
    final isTodayPredicted = predictedDaysWithoutLogs.contains(startOfToday);
    DateTime? todayDate;
    TimeOfDay? todayTime;

    if (isTodayPredicted) {
      todayDate = startOfToday;
      todayTime = _deriveTypicalTimeForWeekday(logs, startOfToday.weekday);
    }

    // Find the next predicted date after today
    DateTime? nextDate;
    TimeOfDay? time;
    int? daysUntilNext;

    final futurePredictedDates = predictedDaysWithoutLogs
        .where((date) => date.isAfter(startOfToday))
        .toList();

    if (futurePredictedDates.isNotEmpty) {
      nextDate = futurePredictedDates.first;
      time = _deriveTypicalTimeForWeekday(logs, nextDate.weekday);
      daysUntilNext = nextDate.difference(startOfToday).inDays;
    } else if (!isTodayPredicted) {
      // If today is not predicted and no future dates, use the first available predicted date
      nextDate = predictedDaysWithoutLogs.first;
      time = _deriveTypicalTimeForWeekday(logs, nextDate.weekday);
    }

    return _PredictionInfo(
      date: nextDate,
      time: time,
      todayDate: todayDate,
      todayTime: todayTime,
      daysUntilNext: daysUntilNext,
    );
  }
}

class _YearTrainingStats {
  final int year;
  final int daysTrained;
  final int predictedRemaining;
  final int totalProjectedSessions;
  final double progress;

  const _YearTrainingStats({
    required this.year,
    required this.daysTrained,
    required this.predictedRemaining,
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
      predictedRemaining: predictedRemaining,
      totalProjectedSessions: totalProjectedSessions,
      progress: progress,
    );
  }
}

class _SegmentedProgressBar extends StatefulWidget {
  final int loggedSessions;
  final int predictedRemaining;
  final int totalSessions;
  final Color accentColor;

  const _SegmentedProgressBar({
    required this.loggedSessions,
    required this.predictedRemaining,
    required this.totalSessions,
    required this.accentColor,
  });

  @override
  State<_SegmentedProgressBar> createState() => _SegmentedProgressBarState();
}

class _SegmentedProgressBarState extends State<_SegmentedProgressBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.totalSessions == 0) {
      return Container(
        height: 8,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
        ),
      );
    }

    final loggedRatio = widget.loggedSessions / widget.totalSessions;
    final predictedRatio = widget.predictedRemaining / widget.totalSessions;
    final remainingRatio = 1.0 - loggedRatio - predictedRatio;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          height: 8,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              // Logged sessions segment
              if (loggedRatio > 0)
                Expanded(
                  flex: (loggedRatio * 1000).round(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.accentColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(4),
                        bottomLeft: const Radius.circular(4),
                        topRight: loggedRatio >= 1.0
                            ? const Radius.circular(4)
                            : Radius.zero,
                        bottomRight: loggedRatio >= 1.0
                            ? const Radius.circular(4)
                            : Radius.zero,
                      ),
                    ),
                  ),
                ),
              // Predicted remaining segment
              if (predictedRatio > 0)
                Expanded(
                  flex: (predictedRatio * 1000).round(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: widget.accentColor.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              // Remaining capacity segment
              if (remainingRatio > 0)
                Expanded(
                  flex: (remainingRatio * 1000).round(),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.only(
                        topRight: const Radius.circular(4),
                        bottomRight: const Radius.circular(4),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
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
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white70,
                fontSize: 12,
              ),
        ),
      ],
    );
  }
}

TimeOfDay? _deriveTypicalTimeForWeekday(List<RoutineLogDto> logs, int weekday) {
  final matches =
      logs.where((log) => log.startTime.weekday == weekday).toList();
  if (matches.isEmpty) return null;
  final totalMinutes = matches.fold<int>(
      0, (sum, log) => sum + log.startTime.hour * 60 + log.startTime.minute);
  final averageMinutes = totalMinutes ~/ matches.length;
  final hour = averageMinutes ~/ 60;
  final minute = averageMinutes % 60;
  return TimeOfDay(hour: hour, minute: minute);
}

String _formatTime(TimeOfDay time) {
  final date = DateTime(0, 1, 1, time.hour, time.minute);
  return DateFormat('h:mm a').format(date);
}

String _formatRelativeDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final tomorrow = today.add(const Duration(days: 1));
  final dateOnly = DateTime(date.year, date.month, date.day);

  final daysDifference = dateOnly.difference(today).inDays;

  if (dateOnly == today) {
    return 'today';
  } else if (dateOnly == tomorrow) {
    return 'tomorrow';
  } else if (daysDifference >= 2 && daysDifference <= 7) {
    return 'in $daysDifference days';
  } else {
    final formatted = DateFormat('EEEE, MMM d').format(date);
    // Make the day name lowercase
    final parts = formatted.split(', ');
    if (parts.length == 2) {
      return '${parts[0].toLowerCase()}, ${parts[1]}';
    }
    return formatted.toLowerCase();
  }
}

class _RoutinePlansSection extends StatelessWidget {
  const _RoutinePlansSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<SupabaseExerciseAndRoutineController>(
      builder: (context, controller, _) {
        final plans = controller.plans;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 188, // 188 * 0.85 ≈ 160px width for consistent cards
              child: GridView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.zero, // Edge-to-edge scroll
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 1,
                  childAspectRatio: 1.0,
                ),
                itemCount: plans.length + 1, // +1 for create new plan card
                itemBuilder: (context, index) {
                  if (index == 0) {
                    // Create new plan card with consistent padding
                    return Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: _CreatePlanCard(
                        onTap: () {
                          final plan = RoutinePlanDto(
                            id: "",
                            name: "",
                            notes: "",
                          );
                          final arguments = RoutinePlanArguments(plan: plan);
                          navigateToRoutinePlanEditor(
                            context: context,
                            arguments: arguments,
                          ).then((createdPlan) {
                            if (createdPlan != null && context.mounted) {
                              navigateWithSlideTransition(
                                context: context,
                                child: RoutinePlanScreen(id: createdPlan.id),
                              );
                            }
                          });
                        },
                      ),
                    );
                  }
                  final plan = plans[index - 1];
                  // Consistent padding across cards; add right padding on last
                  return Padding(
                    padding: EdgeInsets.only(
                      left: 10,
                      right: index == plans.length ? 10 : 0,
                    ),
                    child: RoutinePlanGridItemWidget(
                      plan: plan,
                      onTap: () {
                        navigateWithSlideTransition(
                          context: context,
                          child: RoutinePlanScreen(id: plan.id),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CreatePlanCard extends StatelessWidget {
  final VoidCallback onTap;

  const _CreatePlanCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.03),
              ),
            ),
            child: Center(
              child: FaIcon(
                FontAwesomeIcons.circlePlus,
                size: 32,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
