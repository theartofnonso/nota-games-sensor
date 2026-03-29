import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../logger.dart';
import 'revenue_cat_bootstrap.dart';
import 'revenuecat_subscription_helpers.dart';

/// Result of a store purchase initiated from the custom paywall.
enum SubscriptionPurchaseOutcome {
  success,
  userCancelled,
  failed,
}

int _comparePackages(Package a, Package b) {
  const order = <PackageType>[
    PackageType.weekly,
    PackageType.monthly,
    PackageType.twoMonth,
    PackageType.threeMonth,
    PackageType.sixMonth,
    PackageType.annual,
    PackageType.lifetime,
    PackageType.custom,
    PackageType.unknown,
  ];
  final ia = order.indexOf(a.packageType);
  final ib = order.indexOf(b.packageType);
  final c = ia.compareTo(ib);
  if (c != 0) return c;
  return a.storeProduct.identifier.compareTo(b.storeProduct.identifier);
}

/// Loads offerings and runs purchases via RevenueCat (all product data from the dashboard).
class SubscriptionPurchaseService {
  SubscriptionPurchaseService._();
  static final SubscriptionPurchaseService instance =
      SubscriptionPurchaseService._();

  final _logger = getLogger(className: 'SubscriptionPurchaseService');

  /// Packages from the current (or first) offering — titles, prices, etc. from [Package.storeProduct].
  Future<List<Package>> loadOfferedPackages() async {
    if (!RevenueCatBootstrap.isConfigured) {
      _logger.w('RevenueCat not configured; cannot load offerings.');
      return [];
    }
    try {
      final offerings = await Purchases.getOfferings();
      final offering = RevenueCatSubscriptionHelpers.pickOffering(offerings);
      if (offering == null || offering.availablePackages.isEmpty) {
        _logger.w('No RevenueCat offering with packages.');
        return [];
      }
      final list = List<Package>.from(offering.availablePackages);
      list.sort(_comparePackages);
      return list;
    } catch (e, st) {
      _logger.e('Failed to load offerings', error: e, stackTrace: st);
      return [];
    }
  }

  Future<SubscriptionPurchaseOutcome> purchasePackage(Package package) async {
    if (!RevenueCatBootstrap.isConfigured) {
      return SubscriptionPurchaseOutcome.failed;
    }
    try {
      await Purchases.purchase(PurchaseParams.package(package));
      return SubscriptionPurchaseOutcome.success;
    } on PlatformException catch (e) {
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code == PurchasesErrorCode.purchaseCancelledError) {
        return SubscriptionPurchaseOutcome.userCancelled;
      }
      if (code == PurchasesErrorCode.productAlreadyPurchasedError) {
        final ok = await restorePurchases();
        return ok
            ? SubscriptionPurchaseOutcome.success
            : SubscriptionPurchaseOutcome.failed;
      }
      _logger.w('Purchase failed: $e');
      return SubscriptionPurchaseOutcome.failed;
    } catch (e, st) {
      _logger.e('Purchase failed', error: e, stackTrace: st);
      return SubscriptionPurchaseOutcome.failed;
    }
  }

  Future<bool> restorePurchases() async {
    if (!RevenueCatBootstrap.isConfigured) return false;
    try {
      final info = await Purchases.restorePurchases();
      return RevenueCatSubscriptionHelpers.hasAppAccess(info);
    } catch (e, st) {
      _logger.w('restorePurchases failed', error: e, stackTrace: st);
      return false;
    }
  }
}
