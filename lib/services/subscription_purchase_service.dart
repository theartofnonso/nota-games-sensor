import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../logger.dart';
import 'revenue_cat_bootstrap.dart';
import 'revenuecat_subscription_helpers.dart';

enum SubscriptionPurchaseOutcome { success, userCancelled, failed }

/// [customerInfo] is present on [SubscriptionPurchaseOutcome.success] when the SDK supplied it.
class SubscriptionPurchaseResult {
  const SubscriptionPurchaseResult(this.outcome, [this.customerInfo]);

  final SubscriptionPurchaseOutcome outcome;
  final CustomerInfo? customerInfo;

  static const failed = SubscriptionPurchaseResult(SubscriptionPurchaseOutcome.failed);
  static const userCancelled =
      SubscriptionPurchaseResult(SubscriptionPurchaseOutcome.userCancelled);
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
  final c = order.indexOf(a.packageType).compareTo(order.indexOf(b.packageType));
  if (c != 0) return c;
  return a.storeProduct.identifier.compareTo(b.storeProduct.identifier);
}

/// RevenueCat offerings and purchase / restore for the custom paywall.
class SubscriptionPurchaseService {
  SubscriptionPurchaseService._();
  static final SubscriptionPurchaseService instance =
      SubscriptionPurchaseService._();

  final _logger = getLogger(className: 'SubscriptionPurchaseService');

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

  Future<SubscriptionPurchaseResult> purchasePackage(Package package) async {
    if (!RevenueCatBootstrap.isConfigured) return SubscriptionPurchaseResult.failed;
    try {
      final result = await Purchases.purchase(PurchaseParams.package(package));
      return SubscriptionPurchaseResult(
        SubscriptionPurchaseOutcome.success,
        result.customerInfo,
      );
    } on PlatformException catch (e) {
      return _mapPurchasePlatformException(e);
    } catch (e, st) {
      _logger.e('Purchase failed', error: e, stackTrace: st);
      return SubscriptionPurchaseResult.failed;
    }
  }

  Future<SubscriptionPurchaseResult> _mapPurchasePlatformException(
    PlatformException e,
  ) async {
    final code = PurchasesErrorHelper.getErrorCode(e);
    if (code == PurchasesErrorCode.purchaseCancelledError) {
      return SubscriptionPurchaseResult.userCancelled;
    }
    if (code == PurchasesErrorCode.productAlreadyPurchasedError) {
      final info = await restoreCoachLedPurchases();
      if (info == null) return SubscriptionPurchaseResult.failed;
      return SubscriptionPurchaseResult(
        SubscriptionPurchaseOutcome.success,
        info,
      );
    }
    _logger.w('Purchase failed: $e');
    return SubscriptionPurchaseResult.failed;
  }

  /// Returns [CustomerInfo] only when coach-led entitlements are active after restore.
  Future<CustomerInfo?> restoreCoachLedPurchases() async {
    if (!RevenueCatBootstrap.isConfigured) return null;
    try {
      final info = await Purchases.restorePurchases();
      return RevenueCatSubscriptionHelpers.hasCoachLedSubscription(info)
          ? info
          : null;
    } catch (e, st) {
      _logger.w('restoreCoachLedPurchases failed', error: e, stackTrace: st);
      return null;
    }
  }
}
