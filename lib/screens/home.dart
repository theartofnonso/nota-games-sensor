import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/app_flavor.dart';

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

    // If the user is a coach, don't load data from supabase, this will be done in the coach screen.
    if (AppConfig.isCoach) {
      return;
    }

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

      // Load app data
      final controller = Provider.of<SupabaseExerciseAndRoutineController>(
          context,
          listen: false);
      if (AppConfig.isCoach) {
        return;
      }
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
