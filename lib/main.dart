import 'dart:convert';

import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_authenticator/amplify_authenticator.dart';
import 'package:amplify_datastore/amplify_datastore.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:tracker_app/controllers/exercise_and_routine_controller.dart';
import 'package:tracker_app/controllers/exercise_log_controller.dart';
import 'package:tracker_app/dtos/appsync/routine_log_dto.dart';
import 'package:tracker_app/dtos/appsync/routine_template_dto.dart';
import 'package:tracker_app/dtos/viewmodels/exercise_editor_arguments.dart';
import 'package:tracker_app/dtos/viewmodels/past_routine_log_arguments.dart';
import 'package:tracker_app/repositories/amplify/amplify_exercise_repository.dart';
import 'package:tracker_app/repositories/amplify/amplify_routine_log_repository.dart';
import 'package:tracker_app/repositories/amplify/amplify_routine_plan_repository.dart';
import 'package:tracker_app/repositories/amplify/amplify_routine_template_repository.dart';
import 'package:tracker_app/repositories/exercise_log_repository.dart';
import 'package:tracker_app/screens/editors/exercise_editor_screen.dart';
import 'package:tracker_app/screens/editors/past_routine_log_editor_screen.dart';
import 'package:tracker_app/screens/editors/routine_log_editor_screen.dart';
import 'package:tracker_app/screens/editors/routine_plan_editor_screen.dart';
import 'package:tracker_app/screens/editors/routine_template_editor_screen.dart';
import 'package:tracker_app/screens/exercise/history/exercise_home_screen.dart';
import 'package:tracker_app/screens/home.dart';
import 'package:tracker_app/screens/logs/routine_log_screen.dart';
import 'package:tracker_app/screens/logs/routine_log_summary_screen.dart';
import 'package:tracker_app/onboarding_flow_screen.dart';
import 'package:tracker_app/screens/preferences/settings_screen.dart';
import 'package:tracker_app/screens/routines/routine_plan.dart';
import 'package:tracker_app/screens/routines/routine_plans_screen.dart';
import 'package:tracker_app/screens/routines/routine_template_screen.dart';
import 'package:tracker_app/shared_prefs.dart';
import 'package:tracker_app/utils/date_utils.dart';
import 'package:tracker_app/utils/theme/theme.dart';

import 'amplifyconfiguration.dart';
import 'dtos/appsync/exercise_dto.dart';
import 'dtos/appsync/routine_plan_dto.dart';
import 'dtos/viewmodels/routine_log_arguments.dart';
import 'dtos/viewmodels/routine_plan_arguments.dart';
import 'dtos/viewmodels/routine_template_arguments.dart';
import 'logger.dart';
import 'models/ModelProvider.dart';

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

  SentryWidgetsFlutterBinding.ensureInitialized();

  await SharedPrefs().init();

  await initializeDateFormatting();

  const DarwinInitializationSettings iOSInitializationSettingsDarwin = DarwinInitializationSettings(
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  const AndroidInitializationSettings androidInitializationSettings = AndroidInitializationSettings("app_icon");

  const initializationSettings =
      InitializationSettings(iOS: iOSInitializationSettingsDarwin, android: androidInitializationSettings);

  await FlutterLocalNotificationsPlugin()
      .initialize(initializationSettings, onDidReceiveNotificationResponse: onDidReceiveNotificationResponse);

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
    appRunner: () => runApp(MultiProvider(providers: [
      ChangeNotifierProvider<ExerciseAndRoutineController>(
        create: (BuildContext context) => ExerciseAndRoutineController(
            amplifyExerciseRepository: AmplifyExerciseRepository(),
            amplifyTemplateRepository: AmplifyRoutineTemplateRepository(),
            amplifyPlanRepository: AmplifyRoutinePlanRepository(),
            amplifyLogRepository: AmplifyRoutineLogRepository()),
      ),
      ChangeNotifierProvider<ExerciseLogController>(
          create: (BuildContext context) => ExerciseLogController(ExerciseLogRepository())),
    ], child: const MyApp())),
  );
}

final _router = GoRouter(
  initialLocation: "/",
  navigatorKey: navigatorKey,
  routes: [
    GoRoute(
        path: "/", // Define the path for Home Screen
        builder: (context, state) => const Home(),
        routes: [
          GoRoute(
            path: "shared-workout/:id",
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? "";
              return RoutineTemplateScreen(id: id);
            },
          ),
          GoRoute(
            path: "shared-workout-log/:id",
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? "";
              return RoutineLogScreen(id: id, showSummary: false);
            },
          )
        ]),
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
        return RoutineTemplateEditorScreen(template: args.template, planId: args.planId);
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
        final showSummary = extra["showSummary"] as bool;
        final isEditable = extra['isEditable'] as bool;

        return CustomTransitionPage(
            child: RoutineLogScreen(id: log?.id ?? "", showSummary: showSummary, isEditable: isEditable),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              const curve = Curves.ease;
              final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
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
    GoRoute(
      path: RoutineLogSummaryScreen.routeName,
      pageBuilder: (context, state) {
        final args = state.extra as RoutineLogDto;
        return CustomTransitionPage(
            child: RoutineLogSummaryScreen(log: args),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              const curve = Curves.ease;
              final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              final offsetAnimation = animation.drive(tween);
              return SlideTransition(
                position: offsetAnimation,
                child: child,
              );
            });
      },
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

  @override
  void initState() {
    super.initState();
    _configureAmplify();
  }

  Future<void> _configureAmplify() async {
    /// Only sync data for this year
    final dateRange = theLastYearDateTimeRange();
    final startOfCurrentYear = dateRange.start.toIso8601String();
    final endOfCurrentYear = dateRange.end.toIso8601String();
    try {
      await Amplify.addPlugin(AmplifyAuthCognito());
      final apiPluginOptions = APIPluginOptions(modelProvider: ModelProvider.instance);
      await Amplify.addPlugin(AmplifyAPI(options: apiPluginOptions));
      final datastorePluginOptions = DataStorePluginOptions(syncExpressions: [
        DataStoreSyncExpression(
            RoutineLog.classType, () => RoutineLog.CREATEDAT.between(startOfCurrentYear, endOfCurrentYear)),
      ]);
      await Amplify.addPlugin(AmplifyDataStore(modelProvider: ModelProvider.instance, options: datastorePluginOptions));
      await Amplify.configure(amplifyconfig);
    } on Exception catch (e) {
      debugPrint('Could not configure Amplify: $e');
    }
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
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    //debugPaintSizeEnabled = true;
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp, // Lock orientation to portrait up
    ]);

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: isDarkMode ? Colors.white : Colors.black, // status bar color
        systemNavigationBarIconBrightness: isDarkMode ? Brightness.dark : Brightness.light, // Icon Color
      ),
    );

    return _isFirstLaunch
        ? OnboardingFlowScreen(onPressed: _completeIntro)
        : Authenticator(
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              builder: Authenticator.builder(),
              themeMode: ThemeMode.system,
              theme: TRKRTheme.lightTheme,
              darkTheme: TRKRTheme.darkTheme,
              routerConfig: _router,
            ),
          );
  }
}
