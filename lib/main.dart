import 'dart:convert';

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
import 'package:tracker_app/controllers/exercise_log_controller.dart';
import 'package:tracker_app/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:tracker_app/dtos/appsync/routine_log_dto.dart';
import 'package:tracker_app/dtos/appsync/routine_template_dto.dart';
import 'package:tracker_app/repositories/exercise_log_repository.dart';
import 'package:tracker_app/repositories/supabase/supabase_exercise_repository.dart';
import 'package:tracker_app/repositories/supabase/supabase_routine_log_repository.dart';
import 'package:tracker_app/repositories/supabase/supabase_routine_plan_repository.dart';
import 'package:tracker_app/repositories/supabase/supabase_routine_template_repository.dart';
import 'package:tracker_app/screens/auth/supabase_auth_screen.dart';
import 'package:tracker_app/screens/editors/exercise_editor_screen.dart';
import 'package:tracker_app/screens/editors/past_routine_log_editor_screen.dart';
import 'package:tracker_app/screens/editors/routine_log_editor_screen.dart';
import 'package:tracker_app/screens/editors/routine_plan_editor_screen.dart';
import 'package:tracker_app/screens/editors/routine_template_editor_screen.dart';
import 'package:tracker_app/screens/exercise/history/exercise_home_screen.dart';
import 'package:tracker_app/screens/home.dart';
import 'package:tracker_app/screens/logs/routine_log_screen.dart';
import 'package:tracker_app/onboarding_flow_screen.dart';
import 'package:tracker_app/screens/preferences/settings_screen.dart';
import 'package:tracker_app/screens/routines/routine_plan.dart';
import 'package:tracker_app/screens/routines/routine_plans_screen.dart';
import 'package:tracker_app/screens/routines/routine_template_screen.dart';
import 'package:tracker_app/shared_prefs.dart';
import 'package:tracker_app/supabase_config.dart';
import 'package:tracker_app/utils/theme/theme.dart';

import 'dtos/appsync/exercise_dto.dart';
import 'dtos/appsync/routine_plan_dto.dart';
import 'dtos/viewmodels/routine_log_arguments.dart';
import 'dtos/viewmodels/routine_plan_arguments.dart';
import 'dtos/viewmodels/routine_template_arguments.dart';
import 'dtos/viewmodels/exercise_editor_arguments.dart';
import 'dtos/viewmodels/past_routine_log_arguments.dart';
import 'logger.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Top-level callback function
@pragma('vm:entry-point')
void onDidReceiveNotificationResponse(NotificationResponse response) {
  final String? payload = response.payload;
  if (payload != null) {
    Map<String, dynamic> _ = jsonDecode(payload);

    /// Do nothing for now
  }
}

void main() async {
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

  tz.initializeTimeZones();

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
        // Provide main controller with Supabase repositories
        ChangeNotifierProvider<SupabaseExerciseAndRoutineController>(
          create: (BuildContext context) =>
              SupabaseExerciseAndRoutineController(
            exerciseRepository: SupabaseExerciseRepository(),
            templateRepository: SupabaseRoutineTemplateRepository(),
            planRepository: SupabaseRoutinePlanRepository(),
            logRepository: SupabaseRoutineLogRepository(),
          ),
        ),
        ChangeNotifierProvider<ExerciseLogController>(
            create: (BuildContext context) =>
                ExerciseLogController(ExerciseLogRepository())),
      ], child: const MyApp()));
    },
  );
}

final _router = GoRouter(
  initialLocation: "/",
  navigatorKey: navigatorKey,
  routes: [
    GoRoute(
        path: "/", // Define the path for Home Screen
        builder: (context, state) => const Home()),
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
      path: PastRoutineLogEditorScreen.routeName,
      builder: (context, state) {
        final args = state.extra as PastRoutineLogArguments;
        return PastRoutineLogEditorScreen(log: args.log);
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
      path: ExerciseHomeScreen.routeName,
      builder: (context, state) {
        final args = state.extra as ExerciseDto;
        return ExerciseHomeScreen(exercise: args);
      },
    ),
    GoRoute(
      path: RoutinePlansScreen.routeName,
      builder: (context, state) {
        return RoutinePlansScreen();
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

        return CustomTransitionPage(
            child: RoutineLogScreen(id: log?.id ?? "", isEditable: isEditable),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              const curve = Curves.ease;
              final tween =
                  Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
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
      path: Home.routeName,
      builder: (context, state) => const Home(),
    ),
  ],
);

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isFirstLaunch = SharedPrefs().firstLaunch;
  bool _isAuthenticated = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAuthAndInitialize();
  }

  Future<void> _checkAuthAndInitialize() async {
    // Check if user is already signed in
    final session = Supabase.instance.client.auth.currentSession;
    _isAuthenticated = session != null;

    if (_isAuthenticated) {
      // Initialize data if user is authenticated after the build is complete
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final controller = context.read<SupabaseExerciseAndRoutineController>();
        await controller.initialize();
      });
    }

    // Listen to auth state changes
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final session = data.session;
      setState(() {
        _isAuthenticated = session != null;
      });

      if (_isAuthenticated) {
        // User just signed in, initialize data
        final controller = context.read<SupabaseExerciseAndRoutineController>();
        controller.initialize();
      } else {
        // User signed out, clear data
        final controller = context.read<SupabaseExerciseAndRoutineController>();
        controller.clear();
      }
    });

    setState(() {
      _isLoading = false;
    });
  }

  void _completeIntro() {
    setState(() {
      _isFirstLaunch = false;
      SharedPrefs().firstLaunch = false;
    });
  }

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return MaterialApp(
        themeMode: ThemeMode.system,
        theme: TRKRTheme.lightTheme,
        darkTheme: TRKRTheme.darkTheme,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp, // Lock orientation to portrait up
    ]);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor:
            isDarkMode ? Colors.white : Colors.black, // status bar color
        systemNavigationBarIconBrightness:
            isDarkMode ? Brightness.dark : Brightness.light, // Icon Color
      ),
    );

    // Show onboarding if first launch
    if (_isFirstLaunch) {
      return OnboardingFlowScreen(onPressed: _completeIntro);
    }

    // Show auth screen if not authenticated
    if (!_isAuthenticated) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.system,
        theme: TRKRTheme.lightTheme,
        darkTheme: TRKRTheme.darkTheme,
        home: const SupabaseAuthScreen(),
      );
    }

    // Show main app if authenticated
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,
      theme: TRKRTheme.lightTheme,
      darkTheme: TRKRTheme.darkTheme,
      routerConfig: _router,
    );
  }
}
