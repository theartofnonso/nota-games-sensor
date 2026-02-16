import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Product ID configured in App Store Connect. Update to match your
/// monthly subscription product identifier.
const Set<String> _iapProductIds = <String>{
  'notathletes_monthly',
};

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
    if (!_isAvailable) {
      debugPrint('[IapService] Store not available');
      return [];
    }
    try {
      final response = await _iap.queryProductDetails(_iapProductIds);
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('[IapService] NotFound: ${response.notFoundIDs}');
      }
      _products = response.productDetails;
      debugPrint('[IapService] Loaded ${_products.length} products');
      return _products;
    } catch (e) {
      debugPrint('[IapService] loadProducts error: $e');
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
    if (!_isAvailable) {
      debugPrint('[IapService] Store not available for restore');
      return false;
    }
    _purchasedProductIds.clear();
    try {
      await _iap.restorePurchases();
      // Store delivers restored purchases via purchaseStream asynchronously.
      await Future<void>.delayed(const Duration(seconds: 2));
      return _purchasedProductIds.isNotEmpty;
    } catch (e) {
      debugPrint('[IapService] restorePurchases error: $e');
      return false;
    }
  }

  /// Returns true if the user has an active subscription (from current session or restored).
  bool hasActiveSubscription() {
    return _purchasedProductIds.isNotEmpty;
  }

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
  Future<void> buySubscription(ProductDetails productDetails) async {
    if (!_isAvailable) return;
    final param = PurchaseParam(productDetails: productDetails);
    await _iap.buyNonConsumable(purchaseParam: param);
  }
}

IapService? _iapServiceInstance;

/// Singleton IAP service. Only used on iOS for client subscription flow.
IapService get iapService => _iapServiceInstance ??= IapService();
