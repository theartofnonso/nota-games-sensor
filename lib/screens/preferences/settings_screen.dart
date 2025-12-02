import 'dart:io';
import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:in_app_review/in_app_review.dart';
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
import '../../utils/dialog_utils.dart';
import '../../utils/general_utils.dart';
import '../../utils/notifications_utils.dart';
import '../../utils/navigation_utils.dart';
import '../../utils/uri_utils.dart';
import '../../widgets/backgrounds/trkr_loading_screen.dart';
import '../../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../../widgets/dividers/label_divider.dart';
import '../../widgets/information_containers/information_container_with_background_image.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

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

  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with WidgetsBindingObserver {
  bool _loading = false;

  late WeightUnit _weightUnit;

  String _appVersion = "";

  bool _notificationEnabled = false;

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

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
        minimum: const EdgeInsets.all(10),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Close (X) button in the top-left corner
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const FaIcon(
                    FontAwesomeIcons.solidCircleXmark,
                    size: 24,
                    color: Colors.white,
                  ),
                  onPressed: context.pop,
                ),
              ),
              _TrainingInsightsSection(
                yearStats: yearStats,
                predictionInfo: predictionInfo,
              ),
              const SizedBox(height: 16),
              InformationContainerWithBackgroundImage(
                image: 'images/background.jpg',
                subtitle:
                    "Loving trainware? Your feedback helps us grow and improve.",
                color: Colors.black,
                onTap: _openStoreListing,
                alignmentGeometry: Alignment.center,
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
                            dividerColor: Theme.of(context).colors.dividerColor,
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
                              color: (isDarkMode ? Colors.white : Colors.black)
                                  .withValues(alpha: isDarkMode ? 0.06 : 0.05),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Theme.of(context)
                                    .colors
                                    .borderLight
                                    .withValues(alpha: isDarkMode ? 0.3 : 0.3),
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
                                  color: Theme.of(context).colors.glassLight,
                                  shape: BoxShape.circle,
                                ),
                                child: FaIcon(
                                  FontAwesomeIcons.solidBell,
                                  size: 14,
                                  color:
                                      isDarkMode ? Colors.white : Colors.black,
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
                  onTap: _showSocialLinksBottomSheet,
                  leading: FaIcon(FontAwesomeIcons.globe,
                      color: isDarkMode ? Colors.white70 : Colors.black38),
                  title: Text("Socials",
                      style: Theme.of(context).textTheme.titleMedium),
                  subtitle: const Text("follow us on our socials")),
              ListTile(
                  onTap: _logout,
                  leading: FaIcon(FontAwesomeIcons.arrowRightFromBracket,
                      color: isDarkMode ? Colors.white70 : Colors.black38),
                  title: Text("Logout",
                      style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Text(userEmail)),
              ListTile(
                  onTap: _delete,
                  leading: FaIcon(FontAwesomeIcons.solidCircleXmark,
                      color: isDarkMode ? Colors.white70 : Colors.black38),
                  title: Text("Delete Account",
                      style: Theme.of(context).textTheme.titleMedium),
                  subtitle: Text(userEmail)),
              Center(
                child: Text(
                  _appVersion,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
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

  void _openStoreListing() {
    final InAppReview inAppReview = InAppReview.instance;

    inAppReview.openStoreListing(appStoreId: appStoreId);
  }

  void _showSocialLinksBottomSheet() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
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
              leading: FaIcon(
                FontAwesomeIcons.instagram,
                size: 18,
                color: isDarkMode ? Colors.white70 : Colors.black38,
              ),
              horizontalTitleGap: 10,
              title: Text("Instagram",
                  style: Theme.of(context).textTheme.bodyLarge),
              subtitle: const Text("@ware.train"),
              onTap: () {
                Navigator.of(context).pop();
                _openSocialLink('instagram');
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: FaIcon(
                FontAwesomeIcons.tiktok,
                size: 18,
                color: isDarkMode ? Colors.white70 : Colors.black38,
              ),
              horizontalTitleGap: 10,
              title:
                  Text("TikTok", style: Theme.of(context).textTheme.bodyLarge),
              subtitle: const Text("@ware.train"),
              onTap: () {
                Navigator.of(context).pop();
                _openSocialLink('tiktok');
              },
            ),
          ],
        ),
      ),
    );
  }

  void _openSocialLink(String platform) {
    String url;
    if (platform == 'instagram') {
      url = 'https://www.instagram.com/ware.train';
    } else if (platform == 'tiktok') {
      url = 'https://www.tiktok.com/@ware.train';
    } else {
      return;
    }
    openUrl(url: url, context: context);
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _weightUnit = WeightUnit.fromString(SharedPrefs().weightUnit);
    _getAppVersion();
    _checkNotificationPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
        ? 'Around ${_formatTime(predictionInfo.time!)}'
        : 'Log a few sessions to learn your timing';
    final percentLabel =
        (yearStats.progress * 100).clamp(0, 100).toStringAsFixed(0);
    Widget statGroup({
      required String value,
      required String label,
    }) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: theme.textTheme.displayLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  height: 0.9,
                ) ??
                const TextStyle(
                  color: Colors.white,
                  fontSize: 48,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.white70,
              letterSpacing: 0.4,
            ),
          ),
        ],
      );
    }

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
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sessions this year',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Center(
                                child: statGroup(
                                  value: '${yearStats.daysTrained}',
                                  label: 'Logged sessions',
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            _VsDivider(
                              textColor: Colors.white.withValues(alpha: 0.75),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Center(
                                child: statGroup(
                                  value: '${yearStats.predictedRemaining}',
                                  label: 'Predicted days left',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        LinearProgressIndicator(
                          value: yearStats.progress,
                          minHeight: 6,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          color: theme.colors.vibrantAccent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          yearStats.totalProjectedSessions == 0
                              ? 'Log a few more workouts to project the year.'
                              : '$percentLabel% of projected ${yearStats.totalProjectedSessions} sessions done',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: cardWidth,
                  child: _FrostedCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Next predicted session',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          dateLabel,
                          style: theme.textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timeLabel,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(top: 4),
                              decoration: BoxDecoration(
                                color: theme.colors.vibrantAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Predictions look at your last 30 days of training.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white54,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
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

class _VsDivider extends StatelessWidget {
  final Color textColor;

  const _VsDivider({required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 1,
          height: 24,
          color: textColor.withValues(alpha: 0.4),
        ),
        const SizedBox(height: 4),
        Text(
          'vs',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 1,
          height: 24,
          color: textColor.withValues(alpha: 0.4),
        ),
      ],
    );
  }
}

class _FrostedCard extends StatelessWidget {
  final Widget child;

  const _FrostedCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
          ),
          padding: const EdgeInsets.all(18),
          child: child,
        ),
      ),
    );
  }
}

class _PredictionInfo {
  final DateTime? date;
  final TimeOfDay? time;

  const _PredictionInfo({required this.date, required this.time});

  static _PredictionInfo fromLogs(List<RoutineLogDto> logs) {
    if (logs.isEmpty) return const _PredictionInfo(date: null, time: null);
    final predictedSet = getPredictedTrainingDates(
      historicDateTimes: logs.map((log) => log.startTime).toList(),
      daysAhead: 14,
    );
    final predictedDays = predictedSet.toList()..sort((a, b) => a.compareTo(b));
    if (predictedDays.isEmpty) {
      return const _PredictionInfo(date: null, time: null);
    }

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final nextDate = predictedDays.firstWhere(
      (date) => !date.isBefore(startOfToday),
      orElse: () => predictedDays.first,
    );

    final time = _deriveTypicalTimeForWeekday(logs, nextDate.weekday);
    return _PredictionInfo(date: nextDate, time: time);
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
    return 'Today';
  } else if (dateOnly == tomorrow) {
    return 'Tomorrow';
  } else if (daysDifference >= 2 && daysDifference <= 7) {
    return 'In $daysDifference days';
  } else {
    return DateFormat('EEEE, MMM d').format(date);
  }
}
