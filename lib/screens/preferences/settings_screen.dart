import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:trainware/controllers/nutrition_log_controller.dart';
import 'package:trainware/dtos/nutrition/nutrition_log_dto.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/screens/nutrition/nutrition_tracker_screen.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/config/chat_config.dart';
import 'package:trainware/shared_prefs.dart';
import 'package:trainware/urls.dart';
import 'package:trainware/utils/coach_mapping_utils.dart';
import 'package:trainware/services/chat_unread_service.dart';
import 'package:trainware/services/chat_unread_counts_service.dart';
import 'package:trainware/utils/notifications_utils.dart';
import 'package:trainware/utils/client_access_utils.dart';

import '../../controllers/supabase_exercise_and_routine_controller.dart';
import '../../controllers/access_controller.dart';
import '../../dtos/appsync/routine_log_dto.dart';
import '../../dtos/appsync/routine_template_dto.dart';
import '../../extensions/duration_extension.dart';
import '../../utils/general_utils.dart';
import '../../utils/string_utils.dart';
import '../../services/training_prediction_service.dart';
import '../../utils/calendar_date_logs_sheet.dart';
import '../../utils/navigation_utils.dart';
import '../../utils/uri_utils.dart';
import '../../utils/theme/color_extensions.dart';
import '../../utils/unsaved_workout_utils.dart';
import '../../widgets/backgrounds/trkr_loading_screen.dart';
import '../../widgets/badges/unread_badge.dart';
import '../../widgets/nutrition/calorie_tracking_card.dart';
import '../../widgets/calendar/calendar.dart';
import '../../widgets/information_containers/information_container_with_background_image.dart';
import '../../widgets/icons/custom_icon.dart';
import '../../widgets/settings/delete_account_section.dart';
import '../../widgets/settings/logout_section.dart';
import '../../widgets/settings/coach_feedback_card.dart';
import '../../widgets/settings/coach_ai_chat_card.dart';
import '../../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../../widgets/buttons/opacity_button_widget_two.dart';
import '../../screens/routines/routine_plan.dart';

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

  String _environment = "";
  String _bundleId = "";
  String _deviceToken = "";

  bool _hasCachedSession = false;

  int _chatUnreadCount = 0;
  bool _nutritionInitialized = false;

  /// Stored so [_handleChatUnreadChange] and [dispose] can use it without
  /// [context.read], which can throw when this widget is not in the tree.
  ClientOverrideController? _clientOverrideController;

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

    final accessController = context.watch<ClientOverrideController>();
    final isClientMode = accessController.hasSelectedClient;
    final isCoach = AppConfig.isCoach;

    final userEmail =
        Supabase.instance.client.auth.currentUser?.email ?? "User";
    final controller = context.watch<SupabaseExerciseAndRoutineController>();
    final logs = controller.logs;
    final yearStats = _YearTrainingStats.fromLogs(logs);
    final yearHoursStats = _YearHoursStats.fromLogs(logs);
    final headerName = isClientMode
        ? (accessController.selectedClientName?.trim().isNotEmpty ?? false
            ? accessController.selectedClientName!.trim()
            : 'Client')
        : 'Settings';
    final headerEmail = isClientMode ? '' : userEmail;
    final headerInitials =
        _initialsForName(headerName, isClientMode ? null : headerEmail);
    final nextSession = TrainingPredictionService.getNextPredictedSession(logs);
    final predictionInfo = nextSession != null
        ? _PredictionInfo(
            date: nextSession.date,
            time: nextSession.time,
            daysUntilNext: nextSession.daysUntilNext,
          )
        : const _PredictionInfo(date: null, time: null);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.amber.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      await navigateToChat(context: context);
                    },
                    borderRadius: BorderRadius.circular(28),
                    child: Center(
                      child: FaIcon(
                        FontAwesomeIcons.headset,
                        color: Colors.amber,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_chatUnreadCount > 0)
            Positioned(
              top: -1,
              right: -1,
              child: UnreadBadge(count: _chatUnreadCount),
            ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCoach)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Row(
                        children: [
                          if (headerInitials != null) ...[
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    (isDarkMode ? Colors.white : Colors.black)
                                        .withValues(alpha: 0.18),
                                    (isDarkMode ? Colors.white : Colors.black)
                                        .withValues(alpha: 0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                headerInitials,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  headerName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        color: isDarkMode
                                            ? Colors.white
                                            : Colors.black,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                                if (headerEmail.trim().isNotEmpty)
                                  Text(
                                    headerEmail,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: isDarkMode
                                              ? Colors.white
                                                  .withValues(alpha: 0.6)
                                              : Colors.black
                                                  .withValues(alpha: 0.6),
                                        ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: FaIcon(
                              FontAwesomeIcons.users,
                              color: isDarkMode ? Colors.white70 : Colors.black,
                              size: 18,
                            ),
                            onPressed: _goBackToCoachList,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
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
                        onTap: () => navigateToUnsavedSession(context),
                      ),
                    ),
                  ],
                  if (isCoach && isClientMode) ...[
                    SizedBox(height: _sectionSpacing),
                    const CoachAiChatCard(),
                    SizedBox(height: _sectionSpacing),
                  ],
                  _TrainingInsightsSection(
                    yearStats: yearStats,
                    yearHoursStats: yearHoursStats,
                    predictionInfo: predictionInfo,
                  ),
                  SizedBox(height: _sectionSpacing),
                  _RoutinePlansSection(),
                  _SpacerIfRoutinePlansVisible(),
                  _NutritionSection(),
                  _SpacerIfNutritionVisible(),
                  if (AppConfig.isClient) ...[
                    const CoachFeedbackCard(),
                    SizedBox(height: _sectionSpacing),
                  ],
                  if (!isClientMode) ...[
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
                    SizedBox(height: _sectionSpacing),
                  ],
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
                  _buildAccountActionsEntry(isCoach: isCoach),
                  SizedBox(height: _sectionSpacing),
                  _buildDebugInfoSection(isDarkMode),
                  SizedBox(height: _sectionSpacing),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountActionsEntry({required bool isCoach}) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final surfaceOpacity = theme.brightness == Brightness.dark
        ? onSurface.withValues(alpha: 0.08)
        : onSurface.withValues(alpha: 0.06);
    final contentColor = onSurface.withValues(alpha: 0.75);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: surfaceOpacity,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () => _showAccountActionsBottomSheet(isCoach: isCoach),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.userGear,
                  size: 18,
                  color: contentColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Account',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: contentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAccountActionsBottomSheet({required bool isCoach}) async {
    await showAppActionBottomSheet<void>(
      context: context,
      isDismissible: true,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Account',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (!isCoach) ...[
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Manage subscription'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await showClientSubscriptionSheet(context: context);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Delete my account'),
                onTap: () async {
                  Navigator.of(context).pop();
                  await requestAccountDeletion(
                    context,
                    setLoading: (v) => setState(() => _loading = v),
                  );
                },
              ),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Log out'),
              onTap: () async {
                Navigator.of(context).pop();
                setState(() => _loading = true);
                await performLogout();
                if (mounted) setState(() => _loading = false);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _goBackToCoachList() async {
    if (!mounted) return;
    final routineController =
        context.read<SupabaseExerciseAndRoutineController>();
    final nutritionController = context.read<NutritionLogController>();
    await routineController.clearSelectedClient();
    await nutritionController.clearSelectedClient();
    if (!mounted) return;
    context.go('/coach');
  }

  void _openWebpage() {
    final url = trackrWebUrl;
    openUrl(url: url, context: context);
  }

  void _getAppVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version;
    final buildNumber = packageInfo.buildNumber;
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
      _appVersion = "APP VERSION: $version (BUILD $buildNumber)";
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
          Text(_appVersion, style: style),
          const SizedBox(height: 4),
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

  String? _initialsForName(String name, String? email) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return _initialsFromEmail(email);
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  String? _initialsFromEmail(String? email) {
    if (email == null || email.trim().isEmpty) return null;
    final atIndex = email.indexOf('@');
    if (atIndex <= 0) return email.substring(0, 1).toUpperCase();
    final local = email.substring(0, atIndex);
    if (local.isEmpty) return null;
    return local.substring(0, 1).toUpperCase();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _weightUnit = WeightUnit.fromString(SharedPrefs().weightUnit);
    _getAppVersion();
    _hasCachedSession = SharedPrefs().routineLog.isNotEmpty;
    SharedPrefs().routineLogRevision.addListener(_checkCachedSession);
    _clientOverrideController = context.read<ClientOverrideController>();
    if (AppConfig.isCoach) {
      _chatUnreadCount = 0;
      ChatUnreadCountsService()
          .totalUnreadCount
          .addListener(_handleChatUnreadChange);
      ChatUnreadCountsService()
          .unreadByClientId
          .addListener(_handleChatUnreadChange);
      _clientOverrideController!.addListener(_handleChatUnreadChange);
    } else {
      _chatUnreadCount = ChatUnreadService().unreadCount.value;
      ChatUnreadService().unreadCount.addListener(_handleChatUnreadChange);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final accessController = context.read<ClientOverrideController>();
      if (AppConfig.isCoach) {
        ChatUnreadCountsService().refreshTotalUnreadCount();
        // Sync FAB badge with current selected client's unread count when entering client experience
        _handleChatUnreadChange();
        final clientId = accessController.selectedClientId;
        if (clientId != null) {
          ChatUnreadCountsService().refreshUnreadCountForClient(clientId);
        }
      } else {
        final userId = accessController.userId;
        if (userId == null) return;
        final coachData = await fetchCoachForClient(userId);
        if (coachData == null) return;
        final coachId = coachData['coachId'];
        final coachName = coachData['coachName'];
        if (coachId == null) return;
        // Store coach data for future use (e.g., in navigateToChat)
        accessController.setCoachData(
          coachId: coachId,
          coachName: coachName ?? '',
        );
        await ChatUnreadService().updateContext(
          userId: accessController.userId,
          coachId: coachId,
          userIdOverride: accessController.selectedClientId,
        );
        // Update badge with initial unread count
        _handleChatUnreadChange();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _nutritionInitialized) return;
      _nutritionInitialized = true;
      context.read<NutritionLogController>().initialize();
    });
  }

  void _handleChatUnreadChange() {
    if (!mounted) return;
    final accessController = _clientOverrideController;
    setState(() {
      if (AppConfig.isCoach) {
        if (accessController == null) return;
        final clientId = accessController.selectedClientId;
        _chatUnreadCount = clientId == null
            ? 0
            : (ChatUnreadCountsService().unreadByClientId.value[clientId] ?? 0);
      } else {
        _chatUnreadCount = ChatUnreadService().unreadCount.value;
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SharedPrefs().routineLogRevision.removeListener(_checkCachedSession);
    if (AppConfig.isCoach) {
      ChatUnreadCountsService()
          .totalUnreadCount
          .removeListener(_handleChatUnreadChange);
      ChatUnreadCountsService()
          .unreadByClientId
          .removeListener(_handleChatUnreadChange);
      _clientOverrideController?.removeListener(_handleChatUnreadChange);
    } else {
      ChatUnreadService().unreadCount.removeListener(_handleChatUnreadChange);
    }
    _clientOverrideController = null;
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (AppConfig.isCoach) {
          ChatUnreadCountsService().refreshTotalUnreadCount();
        } else {
          ChatUnreadService().refreshSubscription();
          ChatUnreadService().refreshUnreadCount();
        }
      });
    }
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
                      // Legend
                      Row(
                        children: [
                          _LegendItem(
                            color: Colors.blue,
                            label: 'Logged',
                          ),
                          const SizedBox(width: 16),
                          _LegendItem(
                            color: Colors.blue.withValues(alpha: 0.6),
                            label: 'Predicted',
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
    return Consumer<NutritionLogController>(
      builder: (context, nutritionController, _) {
        final isCoach = AppConfig.isCoach;
        final template = nutritionController.nutritionTemplate;

        // Clients: hide nutrition section when no template exists
        if (!isCoach && template == null) return const SizedBox.shrink();

        if (isCoach && template == null) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: _NutritionCreateRow(),
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

        return NutritionTrackingCarousel(
          goalCalories: goalCalories,
          remainingCalories: remainingCalories,
          proteinTarget: nutritionController.proteinTarget,
          carbsTarget: nutritionController.carbsTarget,
          fatsTarget: nutritionController.fatsTarget,
          consumedProtein: _sumProteinToday(nutritionController.logs),
          consumedCarbs: _sumCarbsToday(nutritionController.logs),
          consumedFats: _sumFatsToday(nutritionController.logs),
          hasLogsToday: hasLogsToday,
          onCardTap: () {
            if (isCoach && nutritionController.logs.isEmpty) {
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
      },
    );
  }
}

/// Coach only: empty state with CTA to create nutrition template.
class _NutritionCreateRow extends StatelessWidget {
  const _NutritionCreateRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colors.vibrantAccent;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final descriptionColor =
        isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black54;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colors.borderLight.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nutrition',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a nutrition template to set calorie and macro targets for this client.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: descriptionColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OpacityButtonWidgetTwo(
              onPressed: () => showNutritionTemplateSheet(context),
              label: 'Create nutrition template',
              buttonColor: accent,
            ),
          ),
        ],
      ),
    );
  }
}

// This function is no longer used - replaced by TrainingPredictionService.deriveTypicalTimeForWeekday

/// Spacer after routine plans - only when that section rendered content.
/// Avoids double gap when client has no plans (section shrinks).
class _SpacerIfRoutinePlansVisible extends StatelessWidget {
  const _SpacerIfRoutinePlansVisible();

  @override
  Widget build(BuildContext context) {
    return Consumer<SupabaseExerciseAndRoutineController>(
      builder: (context, controller, _) {
        final isCoach = AppConfig.isCoach;
        final hasContent = isCoach || controller.plans.isNotEmpty;
        return hasContent
            ? SizedBox(height: _SettingsScreenState._sectionSpacing)
            : const SizedBox.shrink();
      },
    );
  }
}

/// Spacer after nutrition - only when that section rendered content.
/// Avoids double gap when client has no template (section shrinks).
class _SpacerIfNutritionVisible extends StatelessWidget {
  const _SpacerIfNutritionVisible();

  @override
  Widget build(BuildContext context) {
    return Consumer<NutritionLogController>(
      builder: (context, controller, _) {
        final isCoach = AppConfig.isCoach;
        final hasContent = isCoach || controller.nutritionTemplate != null;
        return hasContent
            ? SizedBox(height: _SettingsScreenState._sectionSpacing)
            : const SizedBox.shrink();
      },
    );
  }
}

class _RoutinePlansSection extends StatelessWidget {
  const _RoutinePlansSection();

  @override
  Widget build(BuildContext context) {
    return Consumer<SupabaseExerciseAndRoutineController>(
      builder: (context, controller, _) {
        final isCoach = AppConfig.isCoach;
        final plansEmpty = controller.plans.isEmpty;

        // Clients: hide routine plan section when no plan exists
        if (!isCoach && plansEmpty) return const SizedBox.shrink();

        if (isCoach && plansEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10.0),
            child: _RoutinePlansCreateRow(),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10.0),
          child: _ClientRoutinePlansFrostedCard(),
        );
      },
    );
  }
}

/// Coach only: empty state with title, description, and bottom-sheet-style CTA.
class _RoutinePlansCreateRow extends StatelessWidget {
  const _RoutinePlansCreateRow();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colors.vibrantAccent;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final descriptionColor =
        isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black54;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black12.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Routine Plan',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Build a custom routine plan for this client from the ground up.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: descriptionColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OpacityButtonWidgetTwo(
              onPressed: () => navigateToRoutinePlanEditor(context: context),
              label: 'Create routine plan',
              buttonColor: accent,
            ),
          ),
        ],
      ),
    );
  }
}

/// Frosted card for clients' routine plan: plan name, routine description
/// (notes), then a workout summary (e.g. "3 workouts · 12 exercises").
class _ClientRoutinePlansFrostedCard extends StatelessWidget {
  const _ClientRoutinePlansFrostedCard();

  static const double _radius = 22;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Consumer<SupabaseExerciseAndRoutineController>(
      builder: (context, controller, _) {
        final plans = controller.plans;
        final plan = plans.isNotEmpty ? plans.first : null;
        final templates = plan != null
            ? controller.whereTemplatesForPlan(planId: plan.id)
            : <RoutineTemplateDto>[];

        return GestureDetector(
          onTap: plan != null
              ? () {
                  navigateWithSlideTransition(
                    context: context,
                    child: RoutinePlanScreen(id: plan.id),
                  );
                }
              : null,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(_radius),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.grey.withValues(alpha: 0.2),
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.5),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(_radius),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Opacity(
                        opacity: 0.15,
                        child: Image.asset(
                          'images/1k_Dissolve_Noise_Texture.jpg',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Header: plan name as title, routine description (notes)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plan?.name ?? 'Routine Plan',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.95),
                                  fontSize: 18,
                                ),
                              ),
                              if ((plan?.notes ?? '').isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  plan!.notes,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.white.withValues(alpha: 0.75),
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Workout summary + expand icon on same horizontal plane
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                          child: Builder(
                            builder: (_) {
                              final exerciseCount = templates.fold<int>(0,
                                  (sum, t) => sum + t.exerciseTemplates.length);
                              return Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Wrap(
                                          children: [
                                            CustomIcon(
                                              FontAwesomeIcons.personWalking,
                                              color: theme.colors.vibrantAccent,
                                              width: 20,
                                              height: 20,
                                              iconSize: 10.5,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '$exerciseCount ${pluralize(word: 'Exercise', count: exerciseCount)}',
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                color: Colors.white
                                                    .withValues(alpha: 0.85),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          children: [
                                            CustomIcon(
                                              FontAwesomeIcons.hashtag,
                                              color:
                                                  theme.colorScheme.secondary,
                                              width: 20,
                                              height: 20,
                                              iconSize: 10.5,
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              '${templates.length} ${pluralize(word: 'Session', count: templates.length)}',
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                color: Colors.white
                                                    .withValues(alpha: 0.85),
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                              maxLines: 2,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Material(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    shape: const CircleBorder(),
                                    child: InkWell(
                                      onTap: () {},
                                      customBorder: const CircleBorder(),
                                      child: const Padding(
                                        padding: EdgeInsets.all(10),
                                        child: FaIcon(
                                          FontAwesomeIcons
                                              .arrowUpRightFromSquare,
                                          size: 16,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
