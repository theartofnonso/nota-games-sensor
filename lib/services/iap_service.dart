import 'dart:async';

import 'package:in_app_purchase/in_app_purchase.dart';

/// Product IDs configured in App Store Connect.
/// - notathletes_monthly: Not Athletes Pro (coach-led)
/// - notathletes_solo: Not Athletes (self-coaching)
const Set<String> _iapProductIds = <String>{
  'notathletes_monthly',
  'notathletes_solo',
};

/// Product ID for Pro tier (coach-led).
const String iapProductIdPro = 'notathletes_monthly';

/// Product ID for self-coaching tier (create/manage own routines, no coach).
const String iapProductIdSolo = 'notathletes_solo';

/// IAP service for iOS App Store subscriptions.
/// Handles client subscription checks and purchases via App Store / Play Store.
class IapService {
  IapService() {
    _subscription = InAppPurchase.instance.purchaseStream.listen(
      _onPurchaseUpdated,
    );
  }

  final InAppPurchase _iap = InAppPurchase.instance;
  late final StreamSubscription<List<PurchaseDetails>> _subscription;
  final _purchaseController = StreamController<PurchaseDetails>.broadcast();

  /// Completes when the purchase flow has finished (success or error).
  /// Used to wait for purchase completion from the purchase sheet.
  Stream<PurchaseDetails> get purchaseUpdates => _purchaseController.stream;

  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  final Set<String> _purchasedProductIds = {};

  Future<void> dispose() async {
    await _subscription.cancel();
    await _purchaseController.close();
  }

  void _onPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Show pending UI if needed
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        _purchaseController.add(purchaseDetails);
      } else       if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        final productId = purchaseDetails.productID;
        if (productId.isNotEmpty && _iapProductIds.contains(productId)) {
          _purchasedProductIds.add(productId);
        }
        _purchaseController.add(purchaseDetails);
      }
      if (purchaseDetails.pendingCompletePurchase &&
          purchaseDetails.status != PurchaseStatus.error) {
        InAppPurchase.instance.completePurchase(purchaseDetails);
      }
    }
  }

  /// Returns true if IAP is available (e.g. App Store on iOS).
  Future<bool> isAvailable() async {
    _isAvailable = await _iap.isAvailable();
    return _isAvailable;
  }

  /// Loads products from the store. Call this before showing purchase UI.
  Future<List<ProductDetails>> loadProducts() async {
    if (!_isAvailable) {
      _isAvailable = await _iap.isAvailable();
    }
    if (!_isAvailable) return [];
    try {
      final response = await _iap.queryProductDetails(_iapProductIds);
      _products = response.productDetails;
      return _products;
    } catch (_) {
      return [];
    }
  }

  /// Restores previous purchases. Returns true if any subscription was found.
  /// Purchase details are delivered asynchronously via purchaseStream; we wait
  /// briefly for the store to respond.
  Future<bool> restorePurchases() async {
    if (!_isAvailable) {
      _isAvailable = await _iap.isAvailable();
    }
    if (!_isAvailable) return false;
    _purchasedProductIds.clear();
    try {
      await _iap.restorePurchases();
      await Future<void>.delayed(const Duration(seconds: 2));
      return _purchasedProductIds.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Returns true if the user has an active subscription (from current session or restored).
  bool hasActiveSubscription() {
    return _purchasedProductIds.isNotEmpty;
  }

  /// Returns purchased product IDs (populated after restore or purchase).
  Set<String> get purchasedProductIds => Set.from(_purchasedProductIds);

  /// True if user has the self-coaching subscription (Not Athletes).
  bool get isSelfCoachingSubscription =>
      _purchasedProductIds.contains(iapProductIdSolo);

  /// Clears cached purchase state. Call when starting a fresh check.
  void clearPurchaseCache() {
    _purchasedProductIds.clear();
  }

  /// Checks for existing subscription by restoring purchases.
  /// Returns true if user has active IAP subscription.
  Future<bool> checkHasActiveSubscription() async {
    clearPurchaseCache();
    return restorePurchases();
  }

  /// Initiates purchase for the given product. Purchase updates stream via purchaseUpdates.
  /// applicationUserName is used as an app-scoped account token for backend mapping.
  /// Returns true if the purchase request was sent (sheet should appear); false if not.
  Future<bool> buySubscription(
    ProductDetails productDetails, {
    String? applicationUserName,
  }) async {
    if (!_isAvailable) return false;
    final param = PurchaseParam(
      productDetails: productDetails,
      applicationUserName: applicationUserName,
    );
    return _iap.buyNonConsumable(purchaseParam: param);
  }
}

IapService? _iapServiceInstance;

/// Singleton IAP service. Only used on iOS for client subscription flow.
IapService get iapService => _iapServiceInstance ??= IapService();
