import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

import '../services/iap_service.dart';
import '../utils/dialog_utils.dart';
import '../urls.dart';

Future<bool> requireClientAccess({
  required BuildContext context,
  required String email,
  String? firstName,
  String? lastName,
  bool signOutOnFail = false,
  Future<void> Function()? onDenied,
}) async {
  return _requireClientAccessIap(
    context: context,
    email: email,
    firstName: firstName,
    lastName: lastName,
    signOutOnFail: signOutOnFail,
    onDenied: onDenied,
  );
}

Future<bool> _requireClientAccessIap({
  required BuildContext context,
  required String email,
  String? firstName,
  String? lastName,
  bool signOutOnFail = false,
  Future<void> Function()? onDenied,
}) async {
  // Backend is the source of truth for entitlement/access.
  final hasBackendAccess = await _checkBackendAccess(email: email);
  if (hasBackendAccess) {
    return true;
  }

  final service = iapService;
  final available = await service.isAvailable();
  if (!available) {
    if (context.mounted) {
      showErrorBottomSheet(
        context: context,
        title: 'Purchases unavailable',
        message:
            'In-app purchases are currently unavailable. Please try again later.',
      );
    }
    if (signOutOnFail && onDenied != null) await onDenied();
    return false;
  }

  // First try restore/status check before prompting a new purchase.
  final hasSub = await service.checkHasActiveSubscription();
  if (hasSub) {
    unawaited(_syncBackendActivation(
      email: email,
      firstName: firstName,
      lastName: lastName,
    ));
    return true;
  }

  if (!context.mounted) return false;

  // Go straight to Apple purchase flow (no custom sheet)
  final purchaseCompleted = await _startIapPurchase(context: context);
  if (purchaseCompleted) {
    unawaited(_syncBackendActivation(
      email: email,
      firstName: firstName,
      lastName: lastName,
    ));
    return true;
  }

  if (signOutOnFail && onDenied != null) {
    await onDenied();
  }
  return false;
}

/// Loads the subscription product, starts the Apple purchase flow directly,
/// and waits for the result. No custom sheet—Apple's native UI is shown immediately.
Future<bool> _startIapPurchase({
  required BuildContext context,
}) async {
  final service = iapService;
  final products = await service.loadProducts();
  if (!context.mounted) return false;
  if (products.isEmpty) {
    showErrorBottomSheet(
      context: context,
      title: 'Subscription unavailable',
      message: 'Please try again later.',
    );
    return false;
  }

  final product = products.first;
  final completer = Completer<bool>();
  late final StreamSubscription<PurchaseDetails> purchaseSub;
  purchaseSub = service.purchaseUpdates.listen((details) async {
    if (completer.isCompleted) return;
    if (details.status == PurchaseStatus.purchased ||
        details.status == PurchaseStatus.restored) {
      purchaseSub.cancel();
      completer.complete(true);
    } else if (details.status == PurchaseStatus.error) {
      purchaseSub.cancel();
      completer.complete(false);
      if (context.mounted) {
        showErrorBottomSheet(
          context: context,
          title: 'Something went wrong',
          message: 'Please try again.',
        );
      }
    } else if (details.status == PurchaseStatus.canceled) {
      purchaseSub.cancel();
      completer.complete(false);
    }
  });

  try {
    final sent = await service.buySubscription(product);
    if (!sent) {
      purchaseSub.cancel();
      completer.complete(false);
      if (context.mounted) {
        showErrorBottomSheet(
          context: context,
          title: 'Something went wrong',
          message: 'Please try again.',
        );
      }
      return false;
    }
  } catch (e) {
    purchaseSub.cancel();
    completer.complete(false);
    if (context.mounted) {
      showErrorBottomSheet(
        context: context,
        title: 'Something went wrong',
        message: 'Please try again.',
      );
    }
    return false;
  }

  final success = await completer.future.timeout(
    const Duration(minutes: 5),
    onTimeout: () {
      purchaseSub.cancel();
      return false;
    },
  );
  purchaseSub.cancel();
  return success;
}

Future<void> _syncBackendActivation({
  required String email,
  String? firstName,
  String? lastName,
}) async {
  try {
    final uri = Uri.parse(apiNotathletesBaseUrl).resolve(accountActivatePath);
    final body = <String, String>{'email': email};
    if ((firstName ?? '').trim().isNotEmpty) {
      body['first_name'] = firstName!.trim();
    }
    if ((lastName ?? '').trim().isNotEmpty) {
      body['last_name'] = lastName!.trim();
    }
    await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
  } catch (_) {
    // Best effort only: backend sync should not block app access.
  }
}

Future<bool> _checkBackendAccess({required String email}) async {
  try {
    final uri = Uri.parse(apiNotathletesBaseUrl).resolve(subscriptionStatusPath);
    final response = await http.get(
      uri.replace(queryParameters: {'email': email}),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      return false;
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) return false;

    // Support both old and new payload shapes.
    final access = data['access'];
    if (access is bool) return access;

    final isActive = data['is_active'];
    if (isActive is bool) return isActive;

    return false;
  } catch (_) {
    return false;
  }
}
