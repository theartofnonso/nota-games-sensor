import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/iap_service.dart';
import '../utils/dialog_utils.dart';
import '../urls.dart';
import '../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../widgets/buttons/opacity_button_widget_two.dart';

Future<void> showClientSubscriptionSheet({
  required BuildContext context,
  String? firstName,
  String? lastName,
}) async {
  final user = Supabase.instance.client.auth.currentUser;
  final email = user?.email?.trim();
  if (user == null || email == null || email.isEmpty) {
    showErrorBottomSheet(
      context: context,
      title: 'Unable to manage subscription',
      message: 'Please sign in again and try again.',
    );
    return;
  }

  var isBusy = false;
  String? helperMessage;

  Future<void> restoreFromSheet(
    BuildContext sheetContext,
    void Function(void Function()) setSheetState,
  ) async {
    if (isBusy) return;
    setSheetState(() {
      isBusy = true;
      helperMessage = null;
    });

    final hasSub = await iapService.checkHasActiveSubscription();
    if (hasSub) {
      unawaited(_syncBackendActivation(
        email: email,
        firstName: firstName,
        lastName: lastName,
      ));
      if (sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
      }
      if (context.mounted) {
        showSnackbar(
          context: context,
          message: 'Subscription restored successfully.',
        );
      }
      return;
    }

    if (!sheetContext.mounted) return;
    setSheetState(() {
      isBusy = false;
      helperMessage = 'No active subscription was found to restore.';
    });
  }

  Future<void> subscribeFromSheet(
    BuildContext sheetContext,
    void Function(void Function()) setSheetState,
  ) async {
    if (isBusy) return;
    setSheetState(() {
      isBusy = true;
      helperMessage = null;
    });

    final applicationUserName = user.id;
    if (applicationUserName.trim().isEmpty) {
      if (sheetContext.mounted) {
        setSheetState(() {
          isBusy = false;
          helperMessage = 'Please sign in again and try purchasing.';
        });
      }
      return;
    }

    final purchaseCompleted = await _startIapPurchase(
      context: sheetContext,
      applicationUserName: applicationUserName,
    );
    if (purchaseCompleted) {
      unawaited(_syncBackendActivation(
        email: email,
        firstName: firstName,
        lastName: lastName,
      ));
      if (sheetContext.mounted) {
        Navigator.of(sheetContext).pop();
      }
      if (context.mounted) {
        showSnackbar(
          context: context,
          message: 'Subscription purchase completed.',
        );
      }
      return;
    }

    if (!sheetContext.mounted) return;
    setSheetState(() {
      isBusy = false;
    });
  }

  await showAppBottomSheet<void>(
    context: context,
    isDraggable: false,
    isScrollControlled: false,
    isDismissible: true,
    builder: (sheetContext, _) {
      return StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Subscription',
                  style: Theme.of(sheetContext).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Subscribe to unlock full client coaching access. If you already subscribed on another device, restore first.',
                  style: Theme.of(sheetContext).textTheme.bodyMedium,
                ),
                TextButton(
                  onPressed: isBusy
                      ? null
                      : () => restoreFromSheet(sheetContext, setSheetState),
                  child: const Text('Restore purchase'),
                ),
                const SizedBox(height: 16),
                if (helperMessage != null) ...[
                  Text(
                    helperMessage!,
                    style: Theme.of(sheetContext).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: OpacityButtonWidgetTwo(
                    onPressed: isBusy
                        ? null
                        : () => subscribeFromSheet(sheetContext, setSheetState),
                    label: 'Subscribe',
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

/// Loads the subscription product, starts the Apple purchase flow directly,
/// and waits for the result. No custom sheet—Apple's native UI is shown immediately.
Future<bool> _startIapPurchase({
  required BuildContext context,
  String? applicationUserName,
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
    final sent = await service.buySubscription(
      product,
      applicationUserName: applicationUserName,
    );
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
