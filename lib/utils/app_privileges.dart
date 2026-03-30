import '../app_flavor.dart';
import '../services/client_subscription_service.dart';

/// Centralized privilege checks. Use these instead of raw isCoach/isClient.
///
/// **Client app (RevenueCat):** Subscribers have **app_access** and **coach_access**
/// (coach-led product only).
///
/// - **Coach** (coach app): full access, views clients
/// - **Client** (client app): [hasAccess] implies coach-led subscription
class AppPrivileges {
  AppPrivileges._();

  static bool get isCoach => AppConfig.isCoach;

  /// Client with an active coach-led subscription (not the coach app).
  static bool get isProWithCoach =>
      !isCoach && ClientSubscriptionService.instance.hasAccess;

  /// Client or coach who can create and manage workout templates/plans.
  static bool get canCreateManageRoutines => isCoach || isProWithCoach;
}
