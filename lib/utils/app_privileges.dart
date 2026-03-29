import '../app_flavor.dart';
import '../services/client_subscription_service.dart';

/// Centralized privilege checks. Use these instead of raw isCoach/isClient
/// since solo users share some privileges with coaches but not others.
///
/// **Tiers (client app uses RevenueCat entitlements):**
/// - **Coach** (coach app): full access, views clients
/// - **Coach-tier client** (`coach_access`): coach feedback, coach selection, chat in nav
/// - **Solo client** (`app_access` only): self-coaching UX, skips coach selection
class AppPrivileges {
  AppPrivileges._();

  static bool get isCoach => AppConfig.isCoach;
  static bool get isSelfCoaching =>
      ClientSubscriptionService.instance.isSelfCoaching;

  /// Client with **coach_access** (not the coach app). Requires **app_access** + entitlement.
  static bool get isProWithCoach =>
      !isCoach && ClientSubscriptionService.instance.hasCoachAccess;

  /// Client (solo or pro) who can create and manage their own workout templates/plans.
  static bool get canCreateManageRoutines =>
      isCoach || isSelfCoaching || isProWithCoach;
}
