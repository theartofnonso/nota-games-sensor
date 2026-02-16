import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../services/iap_service.dart';
import '../utils/dialog_utils.dart';
import '../utils/theme/color_extensions.dart';
import '../utils/uri_utils.dart';
import '../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../widgets/buttons/opacity_button_widget_two.dart';

Future<bool> requireClientAccess({
  required BuildContext context,
  required String email,
  bool signOutOnFail = false,
  Future<void> Function()? onDenied,
}) async {
  return _requireClientAccessIap(
    context: context,
    signOutOnFail: signOutOnFail,
    onDenied: onDenied,
  );
}

Future<bool> _requireClientAccessIap({
  required BuildContext context,
  bool signOutOnFail = false,
  Future<void> Function()? onDenied,
}) async {
  final service = iapService;
  final available = await service.isAvailable();
  if (!available) {
    if (context.mounted) {
      showErrorBottomSheet(
        context: context,
        title: 'Store unavailable',
        message: 'In-app purchases are not available. Please try again later.',
      );
    }
    if (signOutOnFail && onDenied != null) await onDenied();
    return false;
  }

  // Check for existing subscription via restore
  final hasSub = await service.checkHasActiveSubscription();
  if (hasSub) return true;
  if (!context.mounted) return false;

  // Go straight to Apple purchase flow (no custom sheet)
  final verified = await _startIapPurchase(context: context);
  if (verified) return true;

  if (signOutOnFail && onDenied != null) {
    await onDenied();
  }
  return false;
}

/// Loads the subscription product, starts the Apple purchase flow directly,
/// and waits for the result. No custom sheet—Apple's native UI is shown immediately.
Future<bool> _startIapPurchase({required BuildContext context}) async {
  final service = iapService;
  final products = await service.loadProducts();
  if (!context.mounted) return false;
  if (products.isEmpty) {
    showErrorBottomSheet(
      context: context,
      title: 'Subscription unavailable',
      message: 'Unable to load subscription. Please try again later.',
    );
    return false;
  }

  final product = products.first;
  final completer = Completer<bool>();
  late final StreamSubscription<PurchaseDetails> purchaseSub;
  purchaseSub = service.purchaseUpdates.listen((details) {
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
          title: 'Purchase failed',
          message: details.error?.message ?? 'Something went wrong. Please try again.',
        );
      }
    } else if (details.status == PurchaseStatus.canceled) {
      purchaseSub.cancel();
      completer.complete(false);
    }
  });

  await service.buySubscription(product);

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

Future<void> _showClientAccessRequiredSheet(BuildContext context) async {
  await showAppBottomSheet<void>(
    context: context,
    isScrollControlled: false,
    isDismissible: false,
    isDraggable: false,
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Complete your signup",
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 8),
          Text(
            "To use the app, complete the survey, set up your subscription. Your coach will be waiting for you in the app.",
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Builder(
              builder: (ctx) {
                final theme = Theme.of(ctx);
                final buttonColor =
                    theme.extension<TRKRColors>()?.vibrantAccent ??
                        theme.colorScheme.primary;
                return OpacityButtonWidgetTwo(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await openUrl(
                      context: ctx,
                      url: 'https://www.notathletes.com/survey',
                    );
                  },
                  label: "Open survey",
                  buttonColor: buttonColor,
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}