import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/controllers/access_controller.dart';
import 'package:trainware/controllers/exercise_log_controller.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/controllers/nutrition_log_controller.dart';
import 'package:trainware/dtos/coach_dto.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';
import 'package:trainware/dtos/appsync/routine_template_dto.dart';
import 'package:trainware/repositories/exercise_log_repository.dart';
import 'package:trainware/repositories/supabase/supabase_coaches_repository.dart';
import 'package:trainware/repositories/supabase/supabase_routine_log_repository.dart';
import 'package:trainware/repositories/supabase/supabase_routine_plan_repository.dart';
import 'package:trainware/repositories/supabase/supabase_routine_template_repository.dart';
import 'package:trainware/screens/auth/supabase_auth_screen.dart';
import 'package:trainware/screens/editors/routine_log_editor_screen.dart';
import 'package:trainware/screens/editors/routine_plan_editor_screen.dart';
import 'package:trainware/screens/editors/routine_template_editor_screen.dart';
import 'package:trainware/screens/home.dart';
import 'package:trainware/screens/logs/coach_feedback_feed_screen.dart';
import 'package:trainware/screens/logs/routine_log_screen.dart';
import 'package:trainware/screens/onboarding/coach_discovery_screen.dart';
import 'package:trainware/screens/welcome_screen.dart';
import 'package:trainware/screens/coach/coach_clients_screen.dart';
import 'package:trainware/screens/preferences/account_settings_screen.dart';
import 'package:trainware/screens/nutrition/nutrition_tracker_screen.dart';
import 'package:trainware/screens/preferences/settings_screen.dart';
import 'package:trainware/screens/routines/routine_plan.dart';
import 'package:trainware/screens/routines/routine_template_screen.dart';
import 'package:trainware/screens/chat/chat_screen.dart';
import 'package:trainware/utils/app_privileges.dart';
import 'package:trainware/utils/shell_tab_paths.dart';
import 'package:trainware/widgets/navigation/routines_shell_page.dart';
import 'package:trainware/shared_prefs.dart';
import 'package:trainware/supabase_config.dart';
import 'package:trainware/utils/theme/system_ui_overlay.dart';
import 'package:trainware/utils/theme/chat_uikit_trainware_theme.dart';
import 'package:trainware/utils/theme/theme.dart';
import 'package:trainware/services/app_startup_service.dart';
import 'package:trainware/services/assigned_coach_service.dart';
import 'package:trainware/services/client_subscription_service.dart';
import 'package:trainware/services/revenue_cat_bootstrap.dart';
import 'package:trainware/services/chat_bootstrap_service.dart';
import 'package:trainware/services/unlisted_client_bootstrap_service.dart';
import 'package:trainware/services/push_token_service.dart'
    as push_permission_service;
import 'package:trainware/utils/navigation_utils.dart';
import 'package:trainware/utils/route_observer.dart';
import 'package:trainware/utils/timezone_utils.dart';
import 'package:trainware/utils/notifications_utils.dart';
import 'package:trainware/widgets/backgrounds/splash_screen.dart';
import 'package:trainware/widgets/coach_selection/profile_completion_gate.dart';
import 'package:trainware/widgets/navigation/main_shell_scaffold.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:agora_chat_uikit/chat_uikit.dart';
import 'package:trainware/config/chat_config.dart';
import 'firebase_options_coach.dart' as coach_options;
import 'firebase_options_coach_unlisted.dart' as coach_unlisted_options;
import 'firebase_options_client.dart' as client_options;
import 'firebase_options_client_unlisted.dart' as client_unlisted_options;

import 'dtos/appsync/routine_plan_dto.dart';
import 'dtos/viewmodels/routine_log_arguments.dart';
import 'dtos/viewmodels/routine_plan_arguments.dart';
import 'dtos/viewmodels/routine_template_arguments.dart';
import 'app_keys.dart';
import 'logger.dart';

Map<String, dynamic>? _pendingNotificationPayload;
int _notificationRetryCount = 0;
const int _maxNotificationRetries = 10;
final _notificationLogger = getLogger(className: "NotificationHandler");

// Top-level callback function
@pragma('vm:entry-point')
void onDidReceiveNotificationResponse(NotificationResponse response) {
  final String? payload = response.payload;
  if (payload == null) return;
  try {
    final decoded = jsonDecode(payload) as Map<String, dynamic>;
    _pendingNotificationPayload = decoded;
    _notificationRetryCount = 0;
    _processPendingNotification();
  } catch (e, stack) {
    _notificationLogger.e("Failed to handle notification payload",
        error: e, stackTrace: stack);
  }
}

void _processPendingNotification() {
  if (_pendingNotificationPayload == null) return;

  final context = rootNavigatorKey.currentContext;
  if (context == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processPendingNotification();
    });
    return;
  }

  final payload = _pendingNotificationPayload!;
  final type = payload['type'] as String?;

  if (!AppConfig.supportsChatAndVideoCalls &&
      (type == 'chat' || type == 'incoming_call')) {
    _pendingNotificationPayload = null;
    _notificationRetryCount = 0;
    return;
  }

  if (type == 'chat') {
    _pendingNotificationPayload = null;
    _notificationRetryCount = 0;
    navigateToChat(context: context);
    return;
  }

  if (type == 'view_log') {
    final logId = payload['logId'] as String?;
    if (logId == null || logId.isEmpty) {
      _pendingNotificationPayload = null;
      return;
    }
    // Same journey for coach and client: load log from cloud, then navigate.
    if (AppConfig.isCoach) {
      _processCoachViewLog(context, logId);
    } else {
      _processClientViewLog(context, logId);
    }
    return;
  }

  if (type == nutritionNudgeNotificationPayloadType) {
    _pendingNotificationPayload = null;
    _notificationRetryCount = 0;
    final ctx = rootNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) {
      ctx.push(NutritionTrackerScreen.routeName);
    }
    return;
  }

  if (type == 'incoming_call') {
    final callerId = payload['callerId'] as String?;
    final callerName = payload['callerName'] as String? ?? '';
    final channelName = payload['channelName'] as String?;
    final callerImageUrl = payload['callerImageUrl'] as String?;
    if (callerId == null ||
        callerId.isEmpty ||
        channelName == null ||
        channelName.isEmpty) {
      _pendingNotificationPayload = null;
      return;
    }
    _pendingNotificationPayload = null;
    _notificationRetryCount = 0;
    navigateToIncomingCall(
      context: context,
      callerId: callerId,
      callerName: callerName,
      channelName: channelName,
      callerImageUrl: (callerImageUrl != null && callerImageUrl.trim().isNotEmpty)
          ? callerImageUrl.trim()
          : null,
    );
    return;
  }

  _pendingNotificationPayload = null;
  _notificationRetryCount = 0;
}

void _processCoachViewLog(BuildContext context, String logId) async {
  final controller = context.read<SupabaseExerciseAndRoutineController>();
  final ownerId = await controller.fetchLogOwnerId(logId);
  if (ownerId == null) {
    if (_notificationRetryCount < _maxNotificationRetries) {
      _notificationRetryCount++;
      Future.delayed(const Duration(milliseconds: 350), () {
        _processPendingNotification();
      });
    } else {
      _notificationLogger
          .w("Failed to find log $logId for notification deep link.");
      _pendingNotificationPayload = null;
      _notificationRetryCount = 0;
    }
    return;
  }
  await controller.loadClientData(clientId: ownerId);
  _pendingNotificationPayload = null;
  _notificationRetryCount = 0;
  if (rootNavigatorKey.currentContext != null) {
    rootNavigatorKey.currentContext!.push('/log/$logId');
  }
}

void _processClientViewLog(BuildContext context, String logId) async {
  final controller = context.read<SupabaseExerciseAndRoutineController>();
  try {
    await controller.refreshRoutineLogsFromCloudForCurrentUser();
  } catch (e) {
    _notificationLogger.w("Failed to refresh logs for deep link: $e");
    _pendingNotificationPayload = null;
    _notificationRetryCount = 0;
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Couldn't load session. Check your connection and try again.",
          ),
        ),
      );
    }
    return;
  }
  _pendingNotificationPayload = null;
  _notificationRetryCount = 0;
  if (rootNavigatorKey.currentContext != null) {
    rootNavigatorKey.currentContext!.push('/log/$logId');
  }
}

Future<void> mainCommon(AppFlavor flavor) async {
  AppConfig.setFlavor(flavor);
  final logger = getLogger(className: "main");

  logger.i("Application starting...");

  WidgetsFlutterBinding.ensureInitialized();

  await ensureLocalTimezoneConfigured();

  // Initialize Firebase: retail vs unlisted iOS apps (see ios/Runner/GoogleService-Info-*.plist).
  final firebaseOptions = switch (flavor) {
    AppFlavor.coach => coach_options.DefaultFirebaseOptions.currentPlatform,
    AppFlavor.coachUnlisted =>
      coach_unlisted_options.DefaultFirebaseOptions.currentPlatform,
    AppFlavor.client => client_options.DefaultFirebaseOptions.currentPlatform,
    AppFlavor.clientUnlisted =>
      client_unlisted_options.DefaultFirebaseOptions.currentPlatform,
  };
  await Firebase.initializeApp(
    options: firebaseOptions,
  );

  if (AppConfig.supportsChatAndVideoCalls) {
    final chatOptions = ChatOptions(
      appKey: ChatConfig.agoraAppKey,
      autoLogin: false,
    );
    if (Platform.isAndroid) {
      chatOptions.enableFCM("160658273085");
    } else if (Platform.isIOS) {
      chatOptions.enableAPNs(ChatConfig.apnsCertName);
      logger.d(
          'APNs cert name for push: "${ChatConfig.apnsCertName}" (must match Agora Console Push Certificate)');
    }
    await ChatUIKit.instance.init(options: chatOptions);
    applyTrainwareChatUIKitTheme();
  }

  await SharedPrefs().init();

  await initializeDateFormatting();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

  if (flavor == AppFlavor.client) {
    await RevenueCatBootstrap.configureForClient();
  }

  const DarwinInitializationSettings iOSInitializationSettingsDarwin =
      DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  const AndroidInitializationSettings androidInitializationSettings =
      AndroidInitializationSettings("app_icon");

  const initializationSettings = InitializationSettings(
      iOS: iOSInitializationSettingsDarwin,
      android: androidInitializationSettings);

  await FlutterLocalNotificationsPlugin().initialize(initializationSettings,
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse);

  final notificationLaunchDetails =
      await FlutterLocalNotificationsPlugin().getNotificationAppLaunchDetails();
  if (notificationLaunchDetails?.didNotificationLaunchApp ?? false) {
    final response = notificationLaunchDetails?.notificationResponse;
    if (response != null) {
      onDidReceiveNotificationResponse(response);
    }
  }

  // FCM: app opened from terminated state by tapping notification
  final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
  if (initialMessage != null) {
    final data = initialMessage.data;
    if (data.isNotEmpty) {
      _pendingNotificationPayload = Map<String, dynamic>.from(data);
      _notificationRetryCount = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processPendingNotification();
      });
    }
  }

  // FCM: app in background, user tapped notification
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    final data = message.data;
    if (data.isEmpty) return;
    _pendingNotificationPayload = Map<String, dynamic>.from(data);
    _notificationRetryCount = 0;
    _processPendingNotification();
  });

  // FCM: app in foreground, incoming call data message
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (!AppConfig.supportsChatAndVideoCalls) return;
    final data = message.data;
    if (data.isEmpty) return;
    final type = data['type'] as String?;
    if (type == 'incoming_call') {
      _pendingNotificationPayload = Map<String, dynamic>.from(data);
      _notificationRetryCount = 0;
      _processPendingNotification();
    }
  });

  void runAppWithProviders() {
    runApp(MultiProvider(providers: [
      ChangeNotifierProvider<ClientOverrideController>(
        create: (BuildContext context) =>
            ClientOverrideController()..initialize(),
      ),
      ChangeNotifierProvider<SupabaseExerciseAndRoutineController>(
        create: (BuildContext context) => SupabaseExerciseAndRoutineController(
          templateRepository: SupabaseRoutineTemplateRepository(),
          planRepository: SupabaseRoutinePlanRepository(),
          logRepository: SupabaseRoutineLogRepository(),
          accessController: context.read<ClientOverrideController>(),
        ),
      ),
      ChangeNotifierProvider<NutritionLogController>(
        create: (BuildContext context) => NutritionLogController(
            accessController: context.read<ClientOverrideController>()),
      ),
      ChangeNotifierProvider<ExerciseLogController>(
          create: (BuildContext context) =>
              ExerciseLogController(ExerciseLogRepository())),
    ], child: const MyApp()));
  }

  if (kReleaseMode) {
    await SentryFlutter.init(
      (options) {
        options.dsn =
            'https://45d4468d9e461dc80082807aea326bd7@o4506338359377920.ingest.sentry.io/4506338360754176';
        options.tracesSampleRate = 1.0;
      },
      appRunner: runAppWithProviders,
    );
  } else {
    runAppWithProviders();
  }
}

/// Parses [value] to RoutineLogDto. Handles both live instances and
/// Map (from go_router state restoration / serialization).
RoutineLogDto? _parseRoutineLogFromExtra(dynamic value) {
  if (value == null) return null;
  if (value is RoutineLogDto) return value;
  if (value is Map<String, dynamic>) {
    try {
      return RoutineLogDto.fromJson(json: value);
    } catch (_) {
      return null;
    }
  }
  return null;
}

GoRouter _createRouter(
  ClientOverrideController accessController,
  Listenable subscriptionRevision,
) {
  return GoRouter(
    initialLocation: "/",
    navigatorKey: rootNavigatorKey,
    observers: [appRouteObserver],
    refreshListenable: Listenable.merge([accessController, subscriptionRevision]),
    redirect: (context, state) {
      final loc = state.matchedLocation;

      if (!AppConfig.isCoach) {
        // Client app: redirect away from coach screen
        if (loc == '/coach') {
          return '/';
        }
        // Without subscription: only home + settings — block shell drill-downs
        if (!AppPrivileges.isProWithCoach) {
          if (loc == kShellRoutinesPath || isShellRoutineTemplatePath(loc)) {
            return '/';
          }
          if (isShellCoachFeedbackPath(loc)) {
            return '/';
          }
        }
        return null;
      }

      // Coach feedback shell tab is for the client app, not coach app.
      if (isShellCoachFeedbackPath(loc)) {
        return accessController.hasSelectedClient ? '/' : '/coach';
      }

      // Coach: shell home at `/` is only valid with a selected client; otherwise
      // send them to the picker (including cold start when `initialLocation` is `/`).
      if (loc == '/' && !accessController.hasSelectedClient) {
        return '/coach';
      }

      // Coach: routine plan / template detail need a selected client; otherwise
      // send them to the client picker (do not redirect to home when client is selected).
      if ((loc == kShellRoutinesPath || isShellRoutineTemplatePath(loc)) &&
          !accessController.hasSelectedClient) {
        return '/coach';
      }

      // Coach app: if no client selected, must be on client selection screen
      // Allow /log/:logId from deep links (user may need to select client after)
      if (!accessController.hasSelectedClient &&
          loc != '/coach' &&
          !loc.startsWith('/log/')) {
        return '/coach';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: Home.routeName,
        redirect: (context, state) => '/',
      ),
      ShellRoute(
        builder: (context, state, child) {
          return ListenableBuilder(
            listenable: ClientSubscriptionService.instance.accessRevision,
            builder: (context, _) {
              return MainShellScaffold(child: child);
            },
          );
        },
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) {
              return CustomTransitionPage(
                key: state.pageKey,
                child: const Home(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
              );
            },
          ),
          GoRoute(
            path: '/coach',
            pageBuilder: (context, state) {
              return CustomTransitionPage(
                key: state.pageKey,
                child: const CoachClientsScreen(
                  navigateToOverviewOnSelect: true,
                ),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
              );
            },
          ),
          GoRoute(
            path: kShellRoutinesPath,
            pageBuilder: (context, state) {
              return CustomTransitionPage(
                key: state.pageKey,
                child: const RoutinesShellPage(),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
              );
            },
          ),
          GoRoute(
            path: '/routine_template/:templateId',
            pageBuilder: (context, state) {
              final id = state.pathParameters['templateId'] ?? '';
              return CustomTransitionPage(
                key: state.pageKey,
                child: RoutineTemplateScreen(
                  id: id,
                  embeddedInShell: true,
                ),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
              );
            },
          ),
          GoRoute(
            path: CoachFeedbackFeedScreen.routeName,
            pageBuilder: (context, state) {
              return CustomTransitionPage(
                key: state.pageKey,
                child: const CoachFeedbackFeedScreen(embeddedInShell: true),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
              );
            },
          ),
          GoRoute(
            path: AccountSettingsScreen.routeName,
            pageBuilder: (context, state) {
              return CustomTransitionPage(
                key: state.pageKey,
                child: const AccountSettingsScreen(embeddedInShell: true),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                  return FadeTransition(
                    opacity: animation,
                    child: child,
                  );
                },
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: RoutineLogEditorScreen.routeName,
        builder: (context, state) {
          final args = state.extra as RoutineLogArguments;
          return RoutineLogEditorScreen(
            log: args.log,
            mode: args.editorMode,
            cached: args.cached,
          );
        },
      ),
      GoRoute(
        path: RoutineTemplateEditorScreen.routeName,
        builder: (context, state) {
          final args = state.extra as RoutineTemplateArguments;
          return RoutineTemplateEditorScreen(
              template: args.template, planId: args.planId);
        },
      ),
      GoRoute(
        path: RoutinePlanEditorScreen.routeName,
        builder: (context, state) {
          final args = state.extra as RoutinePlanArguments?;
          return RoutinePlanEditorScreen(plan: args?.plan);
        },
      ),
      GoRoute(
        path: RoutineTemplateScreen.routeName,
        builder: (context, state) {
          final template = state.extra as RoutineTemplateDto?;
          return RoutineTemplateScreen(id: template?.id ?? "");
        },
      ),
      GoRoute(
        path: RoutinePlanScreen.routeName,
        builder: (context, state) {
          final plan = state.extra as RoutinePlanDto?;
          return RoutinePlanScreen(id: plan?.id ?? "");
        },
      ),
      // Deep link route for universal links (iOS): /log/:logId
      // Used for: (1) client opening session feedback from coach, (2) coach opening client's logged session
      GoRoute(
        path: '/log/:logId',
        pageBuilder: (context, state) {
          final logId = state.pathParameters['logId'] ?? '';
          return CustomTransitionPage(
              child: RoutineLogScreen(
                  id: logId, isEditable: true, showShareOnLoad: false),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(0.0, 1.0);
                const end = Offset.zero;
                const curve = Curves.ease;
                final tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
                final offsetAnimation = animation.drive(tween);
                return SlideTransition(
                  position: offsetAnimation,
                  child: child,
                );
              });
        },
      ),
      GoRoute(
        path: RoutineLogScreen.routeName,
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>?;
          final log = _parseRoutineLogFromExtra(extra?["log"]);
          final isEditable = (extra?['isEditable'] as bool?) ?? true;
          final showShareOnLoad = (extra?['showShareOnLoad'] as bool?) ?? false;

          return CustomTransitionPage(
              child: RoutineLogScreen(
                  id: log?.id ?? "",
                  isEditable: isEditable,
                  showShareOnLoad: showShareOnLoad),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                const begin = Offset(0.0, 1.0);
                const end = Offset.zero;
                const curve = Curves.ease;
                final tween = Tween(begin: begin, end: end)
                    .chain(CurveTween(curve: curve));
                final offsetAnimation = animation.drive(tween);
                return SlideTransition(
                  position: offsetAnimation,
                  child: child,
                );
              });
        },
      ),
      GoRoute(
        path: SettingsScreen.routeName,
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: NutritionTrackerScreen.routeName,
        pageBuilder: (context, state) {
          return CustomTransitionPage<void>(
            key: state.pageKey,
            child: const NutritionTrackerScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              final tween = Tween<Offset>(
                begin: const Offset(0, 1),
                end: Offset.zero,
              ).chain(CurveTween(curve: Curves.easeOutCubic));
              return SlideTransition(
                position: animation.drive(tween),
                child: child,
              );
            },
          );
        },
      ),
      GoRoute(
        path: ChatScreen.routeName,
        pageBuilder: (context, state) {
          if (!AppConfig.supportsChatAndVideoCalls) {
            return CustomTransitionPage(
              key: state.pageKey,
              child: const Home(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            );
          }
          if (!AppConfig.isCoach && !AppPrivileges.isProWithCoach) {
            return CustomTransitionPage(
              key: state.pageKey,
              child: const Home(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            );
          }
          final coachId = state.uri.queryParameters['coachId'] ?? '';
          final coachName = state.uri.queryParameters['coachName'] ?? '';
          final clientUserId = state.uri.queryParameters['clientUserId'] ?? '';
          final clientName = state.uri.queryParameters['clientName'] ?? '';

          // Names may be empty from deep links; chat screen uses fallbacks.
          if (coachId.isEmpty || clientUserId.isEmpty) {
            return CustomTransitionPage(
              key: state.pageKey,
              child: const Home(),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            );
          }

          return CustomTransitionPage(
            key: state.pageKey,
            child: ChatScreen(
              coachId: coachId,
              coachName: coachName,
              clientUserId: clientUserId,
              clientName: clientName,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
          );
        },
      ),
    ],
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  StreamSubscription<Uri>? _appLinksSub;
  late final ClientOverrideController _accessController;
  late final GoRouter _router;
  bool _lastAuthenticated = false;
  bool _lastCoach = false;
  bool _welcomeDismissed = false;
  /// Client first-launch: full-screen coach discovery (pre-auth).
  bool _coachDiscoveryOpen = false;

  /// Preloads coach list while welcome is visible (client first launch).
  Future<List<CoachDto>>? _prefetchedCoachesFuture;
  bool _agoraLifecycleTransitionInFlight = false;

  /// True once startup tasks (auth + subscription for clients) have completed.
  bool _startupComplete = false;
  bool _startupTasksStarted = false;

  @override
  void initState() {
    super.initState();
    _accessController = context.read<ClientOverrideController>();
    _router = _createRouter(
      _accessController,
      ClientSubscriptionService.instance.accessRevision,
    );
    _lastAuthenticated = _accessController.isAuthenticated;
    _lastCoach = AppConfig.isCoach;
    _accessController.addListener(_handleAccessChanged);
    if (Platform.isIOS) {
      _initDeepLinks();
    }
    if (AppConfig.supportsChatAndVideoCalls &&
        _accessController.isAuthenticated &&
        _accessController.userId != null) {
      unawaited(ChatBootstrapService.ensureAgoraAndPushSetup(
          _accessController.userId));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processPendingNotification();
      _runStartupTasksIfReady();
      // [initState] seeds [_lastAuthenticated] from the restored session, so the
      // sign-in transition in [_handleAccessChanged] never runs on cold start — without
      // this, backend FCM registration may never run (unlisted has no Agora path).
      if (_accessController.isAuthenticated) {
        unawaited(push_permission_service.ensureFcmTokenSyncedToBackend());
      }
    });
    // Set preferred orientation once at startup
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    WidgetsBinding.instance.addObserver(this);
    if (AppConfig.isRetailClient && SharedPrefs().firstLaunch) {
      _prefetchedCoachesFuture = SupabaseCoachesRepository().fetchCoaches();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Disconnect Agora when the app is fully backgrounded (not on `inactive`,
    // which also fires for Control Center / task switcher and would churn login).
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_logoutAgoraForBackground());
      return;
    }

    if (state == AppLifecycleState.resumed) {
      unawaited(_restoreAgoraOnResume());
      if (_accessController.isAuthenticated) {
        unawaited(push_permission_service.ensureFcmTokenSyncedToBackend());
      }
    }
  }

  Future<void> _logoutAgoraForBackground() async {
    if (!AppConfig.supportsChatAndVideoCalls) return;
    if (_agoraLifecycleTransitionInFlight) return;
    if (ChatClient.getInstance.currentUserId == null) return;
    _agoraLifecycleTransitionInFlight = true;
    try {
      await ChatClient.getInstance
          .logout(false)
          .timeout(const Duration(seconds: 2));
      // Keep SDK connection cleared from UI kit context (logout(false) skips full unbind).
      ChatUIKitContext.instance.currentUserId = null;
    } catch (_) {
      // Best effort: app may suspend before logout completes.
    } finally {
      _agoraLifecycleTransitionInFlight = false;
    }
  }

  Future<void> _restoreAgoraOnResume() async {
    if (!AppConfig.supportsChatAndVideoCalls) return;
    if (!_accessController.isAuthenticated ||
        _accessController.userId == null) {
      return;
    }
    if (ChatClient.getInstance.currentUserId != null) return;

    // If [resumed] fires while background logout is still running, wait instead
    // of skipping restore (otherwise Agora can stay logged out until next pause).
    for (var i = 0; i < 30 && _agoraLifecycleTransitionInFlight; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    if (!mounted) return;
    if (ChatClient.getInstance.currentUserId != null) return;

    await ChatBootstrapService.ensureAgoraAndPushSetup(
        _accessController.userId);
  }

  void _runStartupTasksIfReady() {
    if (_startupComplete || !mounted) return;
    if (_accessController.isLoading) return;

    if (!_accessController.isAuthenticated) {
      _startupComplete = true;
      if (mounted) setState(() {});
      return;
    }

    if (_startupTasksStarted) return;
    _startupTasksStarted = true;

    final controller = context.read<SupabaseExerciseAndRoutineController>();
    final userId = _accessController.userId;

    unawaited(
      AppStartupService.instance
          .runStartupTasks(
            controller: controller,
            userId: userId,
          )
          .then((_) {
        if (mounted) {
          _startupComplete = true;
          setState(() {});
        }
      }).catchError((e, stack) {
        debugPrint('[Startup] Error: $e\n$stack');
        if (mounted) {
          _startupComplete = true;
          setState(() {});
        }
      }),
    );
  }

  void _handleAccessChanged() {
    if (!mounted) return;
    final isAuthenticated = _accessController.isAuthenticated;
    final isCoach = AppConfig.isCoach;
    final shouldRebuild =
        isAuthenticated != _lastAuthenticated || isCoach != _lastCoach;

    // If startup was previously marked complete in signed-out state, reopen it on
    // sign-in so authenticated startup tasks (including unlisted bootstrap) run.
    if (isAuthenticated && !_lastAuthenticated) {
      _startupComplete = false;
      _startupTasksStarted = false;
    }

    _runStartupTasksIfReady();

    if (isAuthenticated && !_lastAuthenticated && AppConfig.isClient) {
      unawaited(ClientSubscriptionService.instance.refreshSubscriptionStatus());
      if (AppConfig.isUnlistedClient) {
        // Direct call right after sign-in to keep unlisted journey explicit/simple.
        unawaited(UnlistedClientBootstrapService.run());
      }
      // Unlisted: [AppStartupService] runs unlisted bootstrap then refresh in order—
      // avoid a parallel refresh here (would only show coach-profiles without signup in logs).
      if (!AppConfig.isUnlistedClient) {
        unawaited(AssignedCoachService.instance.refreshFromRemote());
      }
    }

    if (isAuthenticated && !_lastAuthenticated) {
      unawaited(push_permission_service.ensureFcmTokenSyncedToBackend());
      // [GoRouter] is long-lived; location survives logout while [MyApp] stays alive.
      // Clear shell routes (e.g. /account-settings) so sign-in lands on home, not the
      // screen where the user logged out.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _router.go('/');
      });
    }

    if (isAuthenticated && (!_lastAuthenticated || isCoach != _lastCoach)) {
      // Mark first launch as complete after successful authentication
      if (SharedPrefs().firstLaunch) {
        SharedPrefs().firstLaunch = false;
      }
      // Data init + chat bootstrap run in _runStartupTasksIfReady (during splash)
    }

    if (!isAuthenticated && _lastAuthenticated) {
      // Covers session expiry / remote sign-out (not only in-app performLogout).
      unawaited(cancelAllTrainingRelatedLocalNotifications());
      if (AppConfig.supportsChatAndVideoCalls) {
        unawaited(ChatBootstrapService.logoutAgoraChat());
      }
      unawaited(RevenueCatBootstrap.logOutIfClient());
      _startupComplete = false;
      _startupTasksStarted = false;
      AppStartupService.instance.reset();
      SharedPrefs().profileSetupComplete = false;
      if (AppConfig.isRetailClient &&
          SharedPrefs().takeClientPreAuthLandingPending()) {
        SharedPrefs().firstLaunch = true;
        _welcomeDismissed = false;
        _coachDiscoveryOpen = false;
        _prefetchedCoachesFuture =
            SupabaseCoachesRepository().fetchCoaches();
      }
      try {
        final controller = context.read<SupabaseExerciseAndRoutineController>();
        controller.clear();
        setState(() {});
      } catch (e) {
        debugPrint('[Auth] Error clearing data: $e');
      }
      // Re-run startup so we complete (unauthenticated) and transition off splash
      _runStartupTasksIfReady();
    }

    if (shouldRebuild) {
      setState(() {});
    }

    _lastAuthenticated = isAuthenticated;
    _lastCoach = isCoach;
  }

  void _initDeepLinks() {
    final appLinks = AppLinks();
    // Handle app opened from universal link (cold start)
    appLinks.getInitialLink().then((Uri? uri) {
      if (!mounted || uri == null) return;
      _navigateFromDeepLink(uri);
    });
    // Handle link while app is running
    _appLinksSub = appLinks.uriLinkStream.listen((Uri uri) {
      if (!mounted) return;
      _navigateFromDeepLink(uri);
    });
  }

  void _navigateFromDeepLink(Uri uri) {
    final path = uri.path;
    if (path.startsWith('/log/') && path.length > 5) {
      if (_accessController.isAuthenticated) {
        _router.go(path);
      }
      return;
    }
    if (path == '/incoming-call') {
      if (!AppConfig.supportsChatAndVideoCalls) return;
      if (!_accessController.isAuthenticated) return;
      final callerId = uri.queryParameters['callerId'];
      final channelName = uri.queryParameters['channelName'];
      final callerName = uri.queryParameters['callerName'] ?? '';
      final callerImageUrl = uri.queryParameters['callerImageUrl'];
      if (callerId == null ||
          callerId.isEmpty ||
          channelName == null ||
          channelName.isEmpty) {
        return;
      }
      final context = rootNavigatorKey.currentContext;
      if (context != null) {
        navigateToIncomingCall(
          context: context,
          callerId: callerId,
          callerName: callerName,
          channelName: channelName,
          callerImageUrl: (callerImageUrl != null && callerImageUrl.trim().isNotEmpty)
              ? callerImageUrl.trim()
              : null,
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accessController.removeListener(_handleAccessChanged);
    _appLinksSub?.cancel();
    super.dispose();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(trkrDarkSystemUiOverlay);

    if (_accessController.isLoading || !_startupComplete) {
      return MaterialApp(
        themeMode: ThemeMode.dark,
        theme: TRKRTheme.darkTheme,
        darkTheme: TRKRTheme.darkTheme,
        home: const SplashScreen(),
      );
    }

    // Client: coach discovery anytime user is signed out (not only first launch),
    // so Sign in → auth can return here via [SupabaseAuthScreen.onDiscoverCoaches].
    if (!_accessController.isAuthenticated &&
        AppConfig.isRetailClient &&
        _coachDiscoveryOpen) {
      _prefetchedCoachesFuture ??=
          SupabaseCoachesRepository().fetchCoaches();
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: TRKRTheme.darkTheme,
        darkTheme: TRKRTheme.darkTheme,
        home: CoachDiscoveryScreen(
          coachesFuture: _prefetchedCoachesFuture,
          onBack: () => setState(() => _coachDiscoveryOpen = false),
          onAcquisitionComplete: () {
            SharedPrefs().firstLaunch = false;
            setState(() {
              _coachDiscoveryOpen = false;
              _welcomeDismissed = true;
            });
            // Auth listener may have refreshed before coach_clients was committed; fetch again.
            unawaited(AssignedCoachService.instance.refreshFromRemote());
          },
          onNeedSignIn: () {
            SharedPrefs().firstLaunch = false;
            setState(() {
              _coachDiscoveryOpen = false;
              _welcomeDismissed = true;
            });
          },
        ),
      );
    }

    // Welcome first: client can discover coaches pre-auth; coach uses single CTA.
    if (SharedPrefs().firstLaunch && !_welcomeDismissed) {
      return WelcomeScreen(
        onPressed: AppConfig.isCoach
            ? () {
                SharedPrefs().firstLaunch = false;
                setState(() => _welcomeDismissed = true);
              }
            : null,
        onDiscoverCoaches: AppConfig.isRetailClient
            ? () => setState(() => _coachDiscoveryOpen = true)
            : null,
        // Unlisted client: same dismiss as retail but no Discover Coaches button.
        onSignIn: AppConfig.isClient
            ? () {
                SharedPrefs().firstLaunch = false;
                setState(() {
                  _welcomeDismissed = true;
                  _coachDiscoveryOpen = false;
                });
              }
            : null,
      );
    }

    // Show auth screen if not authenticated
    if (!_accessController.isAuthenticated) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: TRKRTheme.darkTheme,
        darkTheme: TRKRTheme.darkTheme,
        home: SupabaseAuthScreen(
          onDiscoverCoaches: AppConfig.isRetailClient
              ? () => setState(() => _coachDiscoveryOpen = true)
              : null,
        ),
      );
    }

    // Show main app if authenticated
    final useChatKit = AppConfig.supportsChatAndVideoCalls;
    return ProfileCompletionGate(
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: TRKRTheme.darkTheme,
        darkTheme: TRKRTheme.darkTheme,
        routerConfig: _router,
        supportedLocales: useChatKit
            ? ChatUIKitLocalizations().supportedLocales
            : const [Locale('en')],
        localizationsDelegates: useChatKit
            ? ChatUIKitLocalizations().localizationsDelegates
            : const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
        localeResolutionCallback: useChatKit
            ? ChatUIKitLocalizations().localeResolutionCallback
            : (locale, supported) => locale ?? const Locale('en'),
      ),
    );
  }
}
