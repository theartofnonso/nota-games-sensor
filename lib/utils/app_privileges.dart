import '../app_flavor.dart';
import '../services/client_subscription_service.dart';

/// Centralized privilege checks. Use these instead of raw isCoach/isClient
/// since solo users share some privileges with coaches but not others.
///
/// **Tiers:**
/// - **Coach** (coach app): full access, views clients
/// - **Pro client** (client app, has coach): coach feedback, coach selection
/// - **Solo** (client app, self-coaching): edit own routines/nutrition, no coach
class AppPrivileges {
  AppPrivileges._();

  static bool get isCoach => AppConfig.isCoach;
  static bool get isSelfCoaching =>
      ClientSubscriptionService.instance.isSelfCoaching;

  /// Pro client with a coach (not solo). Coach feedback, coach selection apply.
  static bool get isProWithCoach => !isCoach && !isSelfCoaching;

  /// Client (solo or pro) who can create and manage their own workout templates/plans.
  static bool get canCreateManageRoutines =>
      isCoach || isSelfCoaching || isProWithCoach;
}
