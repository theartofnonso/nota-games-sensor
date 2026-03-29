import 'subscription_catalog.dart';

/// RevenueCat entitlement identifiers for API calls (`presentPaywallIfNeeded`, etc.).
///
/// Values live in [SubscriptionCatalog].
class RevenueCatEntitlements {
  RevenueCatEntitlements._();

  static const String appAccess = SubscriptionCatalog.entitlementAppAccess;
  static const String coachAccess = SubscriptionCatalog.entitlementCoachAccess;
}
