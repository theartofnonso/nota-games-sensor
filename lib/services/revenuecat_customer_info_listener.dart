import 'dart:async';

import 'package:purchases_flutter/purchases_flutter.dart';

import 'client_subscription_service.dart';

bool _registered = false;

/// Refreshes subscription cache when RevenueCat pushes customer info updates.
void registerRevenueCatCustomerInfoListener() {
  if (_registered) return;
  _registered = true;
  Purchases.addCustomerInfoUpdateListener((CustomerInfo info) {
    unawaited(ClientSubscriptionService.instance.syncAccessFromRevenueCat());
  });
}
