import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tracker_app/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:tracker_app/shared_prefs.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../dtos/appsync/routine_log_dto.dart';
import '../dtos/viewmodels/routine_log_arguments.dart';
import '../enums/routine_editor_type_enums.dart';
import '../utils/general_utils.dart';
import '../utils/navigation_utils.dart';
import 'overview_screen.dart';

class Home extends StatefulWidget {
  static const routeName = '/home_screen';

  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: themeGradient(context: context),
        ),
        child: RefreshIndicator(
          onRefresh: _loadAppData,
          child: SafeArea(
            bottom: false,
            child: OverviewScreen(),
          ),
        ),
      ),
    );
  }

  Future<void> _loadAppData() async {
    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);
    await controller.loadUserData();
  }

  Future<void> _userSetup() async {
    try {
      // Get the current Supabase user
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        debugPrint('[UserSetup] No user logged in');
        return;
      }

      final userId = user.id;
      final email = user.email ?? '';

      // Persist to SharedPrefs & analytics
      final prefs = SharedPrefs();
      prefs
        ..userId = userId
        ..userEmail = email;

      Posthog().identify(userId: userId);

      // Load app data
      final controller = Provider.of<SupabaseExerciseAndRoutineController>(
          context,
          listen: false);
      await controller.initialize();
    } catch (e, st) {
      debugPrint('[UserSetup] Error: $e');
      debugPrintStack(stackTrace: st);
      // Still try to load data even if setup fails
      await _loadAppData();
    }
  }

  void _loadCachedLog() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cache = SharedPrefs().routineLog;
      if (cache.isNotEmpty) {
        final json = jsonDecode(cache);
        final routineLog = RoutineLogDto.fromJson(json: json);
        final arguments = RoutineLogArguments(
            log: routineLog, editorMode: RoutineEditorMode.log, cached: true);
        navigateToRoutineLogEditor(context: context, arguments: arguments);
      }
    });
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // Ensure data loading starts immediately
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _userSetup();
    });

    if (Platform.isIOS) {
      FlutterLocalNotificationsPlugin()
          .cancelAll(); // Cancel all notifications including pending workout sessions and regular training reminders
    }
    _loadCachedLog();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
