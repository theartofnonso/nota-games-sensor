import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config/subscription_catalog.dart';
import 'revenue_cat_bootstrap.dart';

/// Entitlement-based helpers for the client app (RevenueCat-recommended gating).
class RevenueCatSubscriptionHelpers {
  RevenueCatSubscriptionHelpers._();

  static bool _isEntitlementActive(CustomerInfo info, String entitlementId) {
    return info.entitlements.all[entitlementId]?.isActive == true;
  }

  /// Subscription gate: user may enter the app.
  static bool hasAppAccess(CustomerInfo info) {
    return _isEntitlementActive(info, SubscriptionCatalog.entitlementAppAccess);
  }

  /// Coach-led tier: coach UI, feedback, chat, coach selection, etc.
  static bool hasCoachAccess(CustomerInfo info) {
    return _isEntitlementActive(info, SubscriptionCatalog.entitlementCoachAccess);
  }

  /// Full client subscription: both entitlements (coach-led product only).
  static bool hasCoachLedSubscription(CustomerInfo info) {
    return hasAppAccess(info) && hasCoachAccess(info);
  }

  /// Cached or network [CustomerInfo]. Returns null if SDK unavailable or on error.
  static Future<CustomerInfo?> fetchCustomerInfo() async {
    if (!RevenueCatBootstrap.isConfigured) return null;
    try {
      return await Purchases.getCustomerInfo();
    } on PlatformException catch (_) {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Best offering to show (current, else first with packages).
  static Offering? pickOffering(Offerings offerings) {
    final current = offerings.current;
    if (current != null && current.availablePackages.isNotEmpty) {
      return current;
    }
    for (final o in offerings.all.values) {
      if (o.availablePackages.isNotEmpty) return o;
    }
    return null;
  }
}
