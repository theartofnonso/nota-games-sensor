import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';

import '../dtos/resubscription_response_dto.dart';
import '../services/iap_service.dart';
import '../urls.dart';
import '../utils/dialog_utils.dart';
import '../utils/theme/color_extensions.dart';
import '../utils/uri_utils.dart';
import '../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../widgets/buttons/opacity_button_widget_two.dart';

/// Result of checkSubscription: hasActiveSubscription, isCustomer.
/// API returns only {hasActiveSubscription, isCustomer} - no products.
({bool hasActiveSubscription, bool isCustomer}) checkSubscriptionResult(
    Map<String, dynamic>? data) {
  if (data == null) {
    return (hasActiveSubscription: false, isCustomer: false);
  }
  return (
    hasActiveSubscription: data['hasActiveSubscription'] == true,
    isCustomer: data['isCustomer'] == true,
  );
}

Future<({bool hasActiveSubscription, bool isCustomer})> checkStripeSubscription({
  required String email,
}) async {
  try {
    final uri = Uri.parse(stripeBaseUrl).resolve(checkStripeSubscriptionPath);
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    debugPrint('[checkSubscription] statusCode=${response.statusCode}');
    debugPrint('[checkSubscription] body=${response.body}');
    if (response.statusCode != 200) {
      return (hasActiveSubscription: false, isCustomer: false);
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>?;
    final result = checkSubscriptionResult(data);
    debugPrint('[checkSubscription] parsed: hasActiveSubscription=${result.hasActiveSubscription}, '
        'isCustomer=${result.isCustomer}');
    return result;
  } catch (e, st) {
    debugPrint('[checkSubscription] error: $e');
    debugPrint('[checkSubscription] stackTrace: $st');
    return (hasActiveSubscription: false, isCustomer: false);
  }
}

/// Fetches products from GET /products. Used when isCustomer but no active subscription.
Future<List<ResubscriptionItemDto>> fetchStripeProducts() async {
  try {
    final uri = Uri.parse(stripeBaseUrl).resolve(stripeProductsPath);
    final response = await http.get(uri);
    debugPrint('[products] statusCode=${response.statusCode}');
    debugPrint('[products] body=${response.body}');
    if (response.statusCode != 200) {
      return [];
    }
    final data = jsonDecode(response.body) as Map<String, dynamic>?;
    final productsRaw = data?['products'] as List<dynamic>? ?? [];
    final items = productsRaw
        .whereType<Map<String, dynamic>>()
        .map(ResubscriptionItemDto.fromJson)
        .toList();
    debugPrint('[products] parsed: ${items.length} products');
    return items;
  } catch (e, st) {
    debugPrint('[products] error: $e');
    debugPrint('[products] stackTrace: $st');
    return [];
  }
}

/// Result of resubscribe API: checkout_url to open, or error message.
/// Backend handles success page in browser; user returns to app and signs in.
Future<({String? checkoutUrl, String? error})> resubscribeStripeSubscription({
  required String email,
  required String priceId,
}) async {
  try {
    final uri = Uri.parse(stripeBaseUrl).resolve(stripeResubscribePath);
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'price_id': priceId,
      }),
    );
    final data = jsonDecode(response.body) as Map<String, dynamic>?;
    if (response.statusCode == 201) {
      final checkoutUrl = data?['checkout_url'] as String?;
      if (checkoutUrl != null && checkoutUrl.isNotEmpty) {
        return (checkoutUrl: checkoutUrl, error: null);
      }
      return (checkoutUrl: null, error: 'Invalid response from server.');
    }
    final err = data?['error'] as String? ?? 'Failed to create checkout session.';
    return (checkoutUrl: null, error: err);
  } catch (e) {
    return (checkoutUrl: null, error: 'Network error. Please try again.');
  }
}

Future<bool> requireClientAccess({
  required BuildContext context,
  required String email,
  bool signOutOnFail = false,
  Future<void> Function()? onDenied,
}) async {
  // On iOS, use Apple In-App Purchase instead of Stripe (App Store requirement).
  if (Platform.isIOS) {
    return _requireClientAccessIos(context: context, signOutOnFail: signOutOnFail, onDenied: onDenied);
  }

  final result = await checkStripeSubscription(email: email);
  if (result.hasActiveSubscription) return true;

  if (result.isCustomer) {
    final products = await fetchStripeProducts();
    if (!context.mounted) return false;
    final verified = await _showResubscribeRequiredSheet(
      context: context,
      email: email,
      subscriptionItems: products,
    );
    if (verified) return true;
  } else {
    if (!context.mounted) return false;
    await _showClientAccessRequiredSheet(context);
  }

  if (signOutOnFail && onDenied != null) {
    await onDenied();
  }
  return false;
}

Future<bool> _requireClientAccessIos({
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

Future<bool> _showResubscribeRequiredSheet({
  required BuildContext context,
  required String email,
  required List<ResubscriptionItemDto> subscriptionItems,
}) async {
  final result = await showAppBottomSheet<bool>(
    context: context,
    isScrollControlled: false,
    isDismissible: true,
    child: _ResubscribeSheet(
      email: email,
      subscriptionItems: subscriptionItems,
    ),
  );
  return result ?? false;
}

class _ResubscribeSheet extends StatefulWidget {
  final String email;
  final List<ResubscriptionItemDto> subscriptionItems;

  const _ResubscribeSheet({
    required this.email,
    required this.subscriptionItems,
  });

  @override
  State<_ResubscribeSheet> createState() => _ResubscribeSheetState();
}

class _ResubscribeSheetState extends State<_ResubscribeSheet> {
  bool _isResubscribing = false;
  int _selectedIndex = 0;

  ResubscriptionItemDto? get _selectedPlan =>
      widget.subscriptionItems.isNotEmpty &&
              _selectedIndex < widget.subscriptionItems.length
          ? widget.subscriptionItems[_selectedIndex]
          : null;

  Future<void> _onResubscribe() async {
    if (_isResubscribing) return;
    final priceId = _selectedPlan?.priceId;
    if (priceId == null || priceId.isEmpty) {
      showErrorBottomSheet(
        context: context,
        title: 'Select a plan',
        message: widget.subscriptionItems.isEmpty
            ? 'No plans available. Please contact support.'
            : 'Please select a plan above.',
      );
      return;
    }
    setState(() => _isResubscribing = true);
    final result = await resubscribeStripeSubscription(
      email: widget.email,
      priceId: priceId,
    );
    if (!mounted) return;
    setState(() => _isResubscribing = false);
    if (result.checkoutUrl != null) {
      await openUrl(context: context, url: result.checkoutUrl!);
      if (!mounted) return;
      Navigator.of(context).pop(false);
      return;
    }
    showErrorBottomSheet(
      context: context,
      title: 'Something went wrong',
      message: 'Please try again or contact support.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor =
        theme.extension<TRKRColors>()?.vibrantAccent ??
            theme.colorScheme.primary;
    final isBusy = _isResubscribing;

    return Padding(
      padding: const EdgeInsets.all(26),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resubscribe to continue',
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.start,
            ),
            const SizedBox(height: 8),
            Text(
              widget.subscriptionItems.isNotEmpty
                  ? 'Your subscription has ended. Choose a plan below and resubscribe to sign in.'
                  : 'Your subscription has ended. Resubscribe below to sign in.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.start,
            ),
            if (widget.subscriptionItems.isNotEmpty) ...[
              const SizedBox(height: 20),
              _SubscriptionPlansCard(
                items: widget.subscriptionItems,
                selectedIndex: _selectedIndex,
                onSelect: (index) => setState(() => _selectedIndex = index),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OpacityButtonWidgetTwo(
                onPressed: isBusy ? null : _onResubscribe,
                label: isBusy ? 'Resubscribing...' : 'Resubscribe',
                buttonColor: buttonColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubscriptionPlansCard extends StatelessWidget {
  final List<ResubscriptionItemDto> items;
  final int selectedIndex;
  final void Function(int index) onSelect;

  const _SubscriptionPlansCard({
    required this.items,
    required this.selectedIndex,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedColor =
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6);
    final borderColor =
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
          InkWell(
            onTap: () => onSelect(i),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          items[i].productName.isNotEmpty
                              ? items[i].productName
                              : 'Subscription',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          items[i].formattedPrice,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: mutedColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (i == selectedIndex)
                    Icon(Icons.check_box, color: Colors.green, size: 22),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
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