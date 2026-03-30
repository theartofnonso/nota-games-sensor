import 'dart:async';

import '../app_flavor.dart';
import '../controllers/supabase_exercise_and_routine_controller.dart';
import 'assigned_coach_service.dart';
import 'chat_bootstrap_service.dart';
import 'client_subscription_service.dart';
import 'coach_clients_service.dart';

/// Runs blocking activities at app startup. Use with [SplashScreen] - show
/// splash until startup tasks complete.
class AppStartupService {
  AppStartupService._();
  static final AppStartupService instance = AppStartupService._();

  /// Runs all startup tasks for authenticated users. Data init and chat
  /// run in parallel; clients also run subscription check; coaches load
  /// their client list so the first screen is ready.
  Future<void> runStartupTasks({
    required SupabaseExerciseAndRoutineController controller,
    required String? userId,
  }) async {
    final tasks = <Future<void>>[
      controller.initialize(),
      ChatBootstrapService.ensureAgoraAndPushSetup(userId),
    ];
    if (AppConfig.isClient) {
      tasks.add(ClientSubscriptionService.instance.refreshSubscriptionStatus());
      tasks.add(AssignedCoachService.instance.refreshFromRemote());
    }
    if (AppConfig.isCoach) {
      tasks.add(
        CoachClientsService.instance.loadClients(coachAuthUserId: userId),
      );
    }
    await Future.wait(tasks);
  }

  /// Resets state (e.g. on logout). Call when user logs out.
  void reset() {
    ClientSubscriptionService.instance.clearCachedAccess();
    CoachClientsService.instance.reset();
    AssignedCoachService.instance.clear();
  }
}
