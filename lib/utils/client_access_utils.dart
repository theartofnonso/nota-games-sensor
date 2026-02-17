import 'dart:async';

import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../services/client_active_service.dart';
import '../services/iap_service.dart';
import '../utils/dialog_utils.dart';
import '../utils/theme/color_extensions.dart';
import '../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../widgets/buttons/opacity_button_widget_two.dart';

Future<bool> requireClientAccess({
  required BuildContext context,
  required String email,
  bool signOutOnFail = false,
  Future<void> Function()? onDenied,
}) async {
  final check = await ClientActiveService().checkActive(email);
  if (check.canSignIn) return true;
  String firstName = '';
  String lastName = '';
  if (!check.exists) {
    final names = await _showNameCollectionSheet(context, email);
    if (names == null) {
      if (signOutOnFail && onDenied != null) await onDenied();
      return false;
    }
    firstName = names.firstName;
    lastName = names.lastName;
  }
  return _requireClientAccessIap(
    context: context,
    email: email,
    firstName: firstName,
    lastName: lastName,
    signOutOnFail: signOutOnFail,
    onDenied: onDenied,
  );
}

Future<({String firstName, String lastName})?> _showNameCollectionSheet(
  BuildContext context,
  String email,
) async {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final result =
      await showAppBottomSheet<({String firstName, String lastName})?>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    isDraggable: false,
    child: Builder(
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final theme = Theme.of(ctx);
        final buttonColor = theme.extension<TRKRColors>()?.vibrantAccent ??
            theme.colorScheme.primary;
        return Padding(
          padding: EdgeInsets.only(
            left: 26,
            right: 26,
            top: 26,
            bottom: 26 + bottomInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Almost there',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your name to continue with your setup.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                email,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: firstNameController,
                cursorColor: isDark ? Colors.white : Colors.black,
                decoration: const InputDecoration(
                  hintText: 'First name',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                textCapitalization: TextCapitalization.words,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: lastNameController,
                cursorColor: isDark ? Colors.white : Colors.black,
                decoration: const InputDecoration(
                  hintText: 'Last name',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
                textCapitalization: TextCapitalization.words,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OpacityButtonWidgetTwo(
                  onPressed: () {
                    FocusScope.of(ctx).unfocus();
                    final fn = firstNameController.text.trim();
                    final ln = lastNameController.text.trim();
                    if (fn.isEmpty || ln.isEmpty) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter first and last name'),
                        ),
                      );
                      return;
                    }
                    Navigator.of(ctx).pop((firstName: fn, lastName: ln));
                  },
                  label: 'Continue to payment',
                  buttonColor: buttonColor,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
  // Defer disposal until sheet has fully closed (avoids "used after disposed")
  Future.delayed(const Duration(milliseconds: 400), () {
    firstNameController.dispose();
    lastNameController.dispose();
  });
  return result;
}

Future<bool> _requireClientAccessIap({
  required BuildContext context,
  required String email,
  String firstName = '',
  String lastName = '',
  bool signOutOnFail = false,
  Future<void> Function()? onDenied,
}) async {
  final service = iapService;
  final available = await service.isAvailable();
  if (!available) {
    final result = await ClientActiveService().activateClient(
      email: email,
      firstName: firstName,
      lastName: lastName,
    );
    if (result.success) return true;
    if (context.mounted) {
      showErrorBottomSheet(
        context: context,
        title: 'Something went wrong',
        message: 'Please try again.',
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
  final verified = await _startIapPurchase(
    context: context,
    email: email,
    firstName: firstName,
    lastName: lastName,
  );
  if (verified) return true;

  if (signOutOnFail && onDenied != null) {
    await onDenied();
  }
  return false;
}

/// Loads the subscription product, starts the Apple purchase flow directly,
/// and waits for the result. No custom sheet—Apple's native UI is shown immediately.
/// On success, calls activate API; backend creates client (if new) and sets is_active.
Future<bool> _startIapPurchase({
  required BuildContext context,
  required String email,
  String firstName = '',
  String lastName = '',
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
      final result = await ClientActiveService().activateClient(
        email: email,
        firstName: firstName,
        lastName: lastName,
      );
      completer.complete(result.success);
      if (!result.success && context.mounted) {
        showErrorBottomSheet(
          context: context,
          title: 'Something went wrong',
          message: 'Please try again.',
        );
      }
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
