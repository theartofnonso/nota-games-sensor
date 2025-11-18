import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:provider/provider.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    return RefreshIndicator(
      onRefresh: _loadAppData,
      child: OverviewScreen(),
    );
  }

  Future<void> _loadAppData() async {
    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);

    // Load data from Supabase
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

      // Analytics
      Posthog().identify(userId: user.id);

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
