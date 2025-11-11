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
import '../utils/theme/color_extensions.dart';
import 'overview_screen.dart';

class Home extends StatefulWidget {
  static const routeName = '/home_screen';

  const Home({super.key});

  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home> with WidgetsBindingObserver {
  bool _hasCachedSession() {
    return SharedPrefs().routineLog.isNotEmpty;
  }

  Future<void> _retryCachedSession() async {
    final cache = SharedPrefs().routineLog;
    if (cache.isEmpty) return;

    try {
      final json = jsonDecode(cache);
      final routineLog = RoutineLogDto.fromJson(json: json);
      
      // Attempt to save to Supabase
      final controller = Provider.of<SupabaseExerciseAndRoutineController>(
          context, listen: false);
      final savedLog = await controller.saveLog(logDto: routineLog);
      
      // Clear cache only if save succeeded
      if (savedLog != null) {
        SharedPrefs().remove(key: SharedPrefs().routineLogKey);
        setState(() {}); // Refresh to hide banner
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Session saved successfully!'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[Retry] Failed to save cached session: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasCachedSession = _hasCachedSession();

    return Column(
      children: [
        if (hasCachedSession)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colors.vibrantAccent.withValues(alpha: 0.1),
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colors.vibrantAccent.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  color: Theme.of(context).colors.vibrantAccent,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Workout session not synced',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colors.vibrantAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _retryCachedSession,
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colors.vibrantAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadAppData,
            child: OverviewScreen(),
          ),
        ),
      ],
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
