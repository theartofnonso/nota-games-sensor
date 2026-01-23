import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:trainware/app_flavor.dart';
import 'package:trainware/controllers/access_controller.dart';
import 'package:trainware/controllers/exercise_log_controller.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/controllers/nutrition_log_controller.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';
import 'package:trainware/dtos/appsync/routine_template_dto.dart';
import 'package:trainware/repositories/exercise_log_repository.dart';
import 'package:trainware/repositories/supabase/supabase_exercise_repository.dart';
import 'package:trainware/repositories/supabase/supabase_routine_log_repository.dart';
import 'package:trainware/repositories/supabase/supabase_routine_plan_repository.dart';
import 'package:trainware/repositories/supabase/supabase_routine_template_repository.dart';
import 'package:trainware/screens/auth/supabase_auth_screen.dart';
import 'package:trainware/screens/coach/decision_logs_screen.dart';
import 'package:trainware/screens/editors/exercise_editor_screen.dart';
import 'package:trainware/screens/editors/routine_log_editor_screen.dart';
import 'package:trainware/screens/editors/routine_plan_editor_screen.dart';
import 'package:trainware/screens/editors/routine_template_editor_screen.dart';
import 'package:trainware/screens/home.dart';
import 'package:trainware/screens/logs/routine_log_screen.dart';
import 'package:trainware/onboarding_flow_screen.dart';
import 'package:trainware/screens/coach/coach_clients_screen.dart';
import 'package:trainware/screens/preferences/settings_screen.dart';
import 'package:trainware/screens/routines/routine_plan.dart';
import 'package:trainware/screens/routines/routine_template_screen.dart';
import 'package:trainware/screens/chat/chat_screen.dart';
import 'package:trainware/config/chat_config.dart';
import 'package:trainware/shared_prefs.dart';
import 'package:trainware/supabase_config.dart';
import 'package:trainware/services/chat_unread_service.dart';
import 'package:trainware/utils/theme/theme.dart';
import 'package:trainware/utils/route_observer.dart';
import 'package:trainware/utils/timezone_utils.dart';
import 'package:trainware/widgets/backgrounds/trkr_loading_screen.dart';

import 'dtos/appsync/routine_plan_dto.dart';
import 'dtos/viewmodels/routine_log_arguments.dart';
import 'dtos/viewmodels/routine_plan_arguments.dart';
import 'dtos/viewmodels/routine_template_arguments.dart';
import 'dtos/viewmodels/exercise_editor_arguments.dart';
import 'logger.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
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

  final context = navigatorKey.currentContext;
  if (context == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processPendingNotification();
    });
    return;
  }

  final payload = _pendingNotificationPayload!;
  final type = payload['type'] as String?;

  if (type == 'view_log') {
    final logId = payload['logId'] as String?;
    if (logId == null || logId.isEmpty) {
      _pendingNotificationPayload = null;
      return;
    }

    final controller = context.read<SupabaseExerciseAndRoutineController>();
    final log = controller.logWhereId(id: logId);

    if (log == null) {
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

    _pendingNotificationPayload = null;
    _notificationRetryCount = 0;
    return;
  }

  _pendingNotificationPayload = null;
  _notificationRetryCount = 0;
}

Future<void> main() async {
  await mainCommon(AppFlavor.client);
}

Future<void> mainCommon(AppFlavor flavor) async {
  AppConfig.setFlavor(flavor);
  final logger = getLogger(className: "main");

  logger.i("Application starting...");

  WidgetsFlutterBinding.ensureInitialized();

  await SharedPrefs().init();

  await initializeDateFormatting();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.supabaseUrl,
    anonKey: SupabaseConfig.supabaseAnonKey,
  );

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

  tz.initializeTimeZones();
  await configureLocalTimezone();

  await SentryFlutter.init(
    (options) {
      options.dsn = kReleaseMode
          ? 'https://45d4468d9e461dc80082807aea326bd7@o4506338359377920.ingest.sentry.io/4506338360754176'
          : "";
      // Set tracesSampleRate to 1.0 to capture 100% of transactions for performance monitoring.
      // We recommend adjusting this value in production.
      options.tracesSampleRate = 1.0;
    },
    appRunner: () {
      return runApp(MultiProvider(providers: [
        ChangeNotifierProvider<AccessController>(
          create: (BuildContext context) => AccessController()..initialize(),
        ),
        // Provide main controller with Supabase repositories
        ChangeNotifierProvider<SupabaseExerciseAndRoutineController>(
          create: (BuildContext context) =>
              SupabaseExerciseAndRoutineController(
            exerciseRepository: SupabaseExerciseRepository(),
            templateRepository: SupabaseRoutineTemplateRepository(),
            planRepository: SupabaseRoutinePlanRepository(),
            logRepository: SupabaseRoutineLogRepository(),
            accessController: context.read<AccessController>(),
          ),
        ),
        ChangeNotifierProvider<NutritionLogController>(
          create: (BuildContext context) => NutritionLogController(
              accessController: context.read<AccessController>()),
        ),
        ChangeNotifierProvider<ExerciseLogController>(
            create: (BuildContext context) =>
                ExerciseLogController(ExerciseLogRepository())),
      ], child: const MyApp()));
    },
  );
}

GoRouter _createRouter(AccessController accessController) {
  return GoRouter(
    initialLocation: "/",
    navigatorKey: navigatorKey,
    observers: [appRouteObserver],
    refreshListenable: accessController,
    redirect: (context, state) {
      if (!AppConfig.isCoach) {
        if (state.matchedLocation == '/coach') {
          return '/';
        }
        return null;
      }

      if (!accessController.isClientMode && state.matchedLocation != '/coach') {
        return '/coach';
      }
      return null;
    },
    routes: [
      GoRoute(
          path: "/", // Define the path for Home Screen
          builder: (context, state) => const Home()),
      GoRoute(
        path: '/coach',
        builder: (context, state) => const CoachClientsScreen(
          navigateToOverviewOnSelect: true,
        ),
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
        path: ExerciseEditorScreen.routeName,
        builder: (context, state) {
          final args = state.extra as ExerciseEditorArguments?;
          return ExerciseEditorScreen(exercise: args?.exercise);
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
      GoRoute(
        path: RoutineLogScreen.routeName,
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, dynamic>;
          final log = extra["log"] as RoutineLogDto?;
          final isEditable = extra['isEditable'] as bool;
          final showShareOnLoad = (extra['showShareOnLoad'] as bool?) ?? false;

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
        path: DecisionLogsScreen.routeName,
        builder: (context, state) {
          final clientId = state.extra as String?;
          return DecisionLogsScreen(clientId: clientId ?? '');
        },
      ),
      GoRoute(
        path: ChatScreen.routeName,
        builder: (context, state) {
          // Get adminUserId from state params or use default from config
          final adminUserId = state.uri.queryParameters['adminUserId'] ??
              ChatConfig.adminUserId;
          return ChatScreen(adminUserId: adminUserId);
        },
      ),
      GoRoute(
        path: Home.routeName,
        builder: (context, state) => const Home(),
      ),
    ],
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isFirstLaunch = SharedPrefs().firstLaunch;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  late final AccessController _accessController;
  late final GoRouter _router;
  bool _lastAuthenticated = false;
  bool _lastCoach = false;

  @override
  void initState() {
    super.initState();
    _accessController = context.read<AccessController>();
    _router = _createRouter(_accessController);
    _lastAuthenticated = _accessController.isAuthenticated;
    _lastCoach = AppConfig.isCoach;
    _accessController.addListener(_handleAccessChanged);
    _listenToConnectivity();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _processPendingNotification();
    });
  }

  void _handleAccessChanged() {
    if (!mounted) return;
    final isAuthenticated = _accessController.isAuthenticated;
    final isCoach = AppConfig.isCoach;
    final shouldRebuild =
        isAuthenticated != _lastAuthenticated || isCoach != _lastCoach;

    if (isAuthenticated && (!_lastAuthenticated || isCoach != _lastCoach)) {
      try {
        final controller = context.read<SupabaseExerciseAndRoutineController>();
        controller.initialize();
      } catch (e) {
        debugPrint('[Auth] Error initializing data: $e');
      }
    }

    if (!isAuthenticated && _lastAuthenticated) {
      try {
        final controller = context.read<SupabaseExerciseAndRoutineController>();
        controller.clear();
        setState(() {
          _isFirstLaunch = true;
          SharedPrefs().firstLaunch = true;
        });
        ChatUnreadService().clear();
      } catch (e) {
        debugPrint('[Auth] Error clearing data: $e');
      }
    }

    if (isAuthenticated) {
      final accessController = _accessController;
      ChatUnreadService().updateContext(
        userId: accessController.userId,
        coachId: ChatConfig.adminUserId,
        userIdOverride: accessController.clientOverrideId,
      );
    }

    if (shouldRebuild) {
      setState(() {});
    }

    _lastAuthenticated = isAuthenticated;
    _lastCoach = isCoach;
  }

  void _completeIntro() {
    setState(() {
      _isFirstLaunch = false;
      SharedPrefs().firstLaunch = false;
    });
  }

  void _listenToConnectivity() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!mounted) return;

      final current =
          results.isNotEmpty ? results.last : ConnectivityResult.none;
      final isOnline = current != ConnectivityResult.none;
      if (!isOnline || !_accessController.isAuthenticated) return;

      try {
        final controller = context.read<SupabaseExerciseAndRoutineController>();
        // ignore: discarded_futures
        controller.syncRoutineLogs();
      } catch (e) {
        debugPrint('[Connectivity] Error triggering sync: $e');
      }
    });
  }

  @override
  void dispose() {
    _accessController.removeListener(_handleAccessChanged);
    _connectivitySub?.cancel();
    super.dispose();
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    if (_accessController.isLoading) {
      return MaterialApp(
        themeMode: ThemeMode.dark,
        theme: TRKRTheme.darkTheme,
        darkTheme: TRKRTheme.darkTheme,
        home: const TRKRLoadingScreen(),
      );
    }

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );

    // Show onboarding if first launch
    if (_isFirstLaunch) {
      return OnboardingFlowScreen(onPressed: _completeIntro);
    }

    // Show auth screen if not authenticated
    if (!_accessController.isAuthenticated) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: TRKRTheme.darkTheme,
        darkTheme: TRKRTheme.darkTheme,
        home: const SupabaseAuthScreen(),
      );
    }

    if (!_accessController.isRoleResolved) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: TRKRTheme.darkTheme,
        darkTheme: TRKRTheme.darkTheme,
        home: const TRKRLoadingScreen(),
      );
    }

    // Show main app if authenticated
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: TRKRTheme.darkTheme,
      darkTheme: TRKRTheme.darkTheme,
      routerConfig: _router,
    );
  }
}
