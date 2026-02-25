import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_flavor.dart';
import '../urls.dart';
import '../utils/dialog_utils.dart';
import '../utils/general_utils.dart';
import '../utils/uri_utils.dart';
import '../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../widgets/buttons/opacity_button_widget_two.dart';
import 'iap_service.dart';

const String _privacyPolicyUrl = 'https://www.notathletes.com/privacy';

class ClientSubscriptionService {
  ClientSubscriptionService._();
  static final ClientSubscriptionService instance =
      ClientSubscriptionService._();

  /// In-memory cache of subscription status. Null = not yet checked.
  /// Checked once at app load when user authenticates; reused at gate points.
  bool? _cachedAccess;

  /// Shared future for in-flight refresh. Prevents duplicate fetches when
  /// app-load refresh and first gate check overlap.
  Future<void>? _refreshInProgress;

  /// Fetches subscription status from backend and caches in memory.
  /// Non-blocking when called at app load. Gate points await this; if a
  /// refresh is already in progress, they await the same future.
  Future<void> refreshSubscriptionStatus() async {
    if (!AppConfig.isClient) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.id.trim().isEmpty) {
      _cachedAccess = null;
      _refreshInProgress = null;
      return;
    }

    if (_refreshInProgress != null) {
      await _refreshInProgress;
      return;
    }

    final future = _fetchBackendAccess(userId: user.id).then((access) {
      _cachedAccess = access;
    });
    _refreshInProgress = future;
    try {
      await future;
    } finally {
      _refreshInProgress = null;
    }
  }

  /// Clears cached status (e.g. on logout).
  void clearCachedAccess() {
    _cachedAccess = null;
    _refreshInProgress = null;
  }

  /// Checks cached subscription status only. No refresh/API calls at gate points.
  /// Cache is populated at app launch (splash screen).
  Future<bool> ensureAccess({
    required BuildContext context,
    required String blockedMessage,
  }) async {
    if (!AppConfig.isClient) return true;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.id.trim().isEmpty) return false;

    if (_cachedAccess == true) return true;

    // Cached false or null: show paywall (no refresh - cache set at splash)
    if (!context.mounted) return false;
    showSnackbar(context: context, message: blockedMessage);
    await showPaywall(context: context);
    return false;
  }

  /// Called by paywall when purchase or restore succeeds. Refreshes the
  /// in-memory cache so subsequent gate checks pass without another backend call.
  Future<void> onPaywallSuccess() async {
    await refreshSubscriptionStatus();
  }

  Future<void> showPaywall({required BuildContext context}) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.id.trim().isEmpty) {
      showErrorBottomSheet(
        context: context,
        title: 'Unable to manage subscription',
        message: 'Please sign in again and try again.',
      );
      return;
    }

    await showAppBottomSheet<void>(
      context: context,
      isDraggable: false,
      isScrollControlled: true,
      isDismissible: true,
      child: _ClientSubscriptionPaywallSheet(
        userId: user.id,
        parentContext: context,
        service: this,
      ),
    );
  }

  Future<List<ProductDetails>> loadProducts() => iapService.loadProducts();

  Future<bool> restorePurchase() => iapService.checkHasActiveSubscription();

  Future<bool> startPurchase({
    required BuildContext context,
    required String userId,
    ProductDetails? product,
  }) {
    return _startIapPurchase(
      context: context,
      applicationUserName: userId,
      productOverride: product,
    );
  }

  Future<bool?> _fetchBackendAccess({
    required String userId,
  }) async {
    try {
      final uri =
          Uri.parse(apiNotathletesBaseUrl).resolve(subscriptionStatusPath);
      final response = await http.get(
        uri.replace(queryParameters: {'user_id': userId}),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) return null;
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic>) return null;
      return data['access'] == true;
    } catch (_) {
      return null;
    }
  }
}

Future<bool> _startIapPurchase({
  required BuildContext context,
  String? applicationUserName,
  ProductDetails? productOverride,
}) async {
  final service = iapService;
  final products =
      productOverride == null ? await service.loadProducts() : null;
  if (!context.mounted) return false;
  if (productOverride == null && (products == null || products.isEmpty)) {
    showErrorBottomSheet(
      context: context,
      title: 'Subscription unavailable',
      message: 'Please try again later.',
    );
    return false;
  }

  final product = productOverride ?? products!.first;
  final completer = Completer<bool>();
  var purchaseRequestSent = false;
  late final StreamSubscription<PurchaseDetails> purchaseSub;
  purchaseSub = service.purchaseUpdates.listen((details) async {
    if (completer.isCompleted) return;
    if (!purchaseRequestSent) return;

    if (details.status == PurchaseStatus.purchased ||
        details.status == PurchaseStatus.restored) {
      purchaseSub.cancel();
      completer.complete(true);
    } else if (details.status == PurchaseStatus.error) {
      if (_looksLikeAlreadyOwned(details)) {
        final hasSub = await service.checkHasActiveSubscription();
        purchaseSub.cancel();
        completer.complete(hasSub);
        if (!hasSub && context.mounted) {
          showErrorBottomSheet(
            context: context,
            title: 'Subscription unavailable',
            message: 'Please try restoring your purchase.',
          );
        }
        return;
      }
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
    purchaseRequestSent = true;
  } catch (_) {
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

bool _looksLikeAlreadyOwned(PurchaseDetails details) {
  final error = details.error;
  if (error == null) return false;
  final message = '${error.code} ${error.message}'.toLowerCase();
  return message.contains('already') ||
      message.contains('owned') ||
      message.contains('active subscription') ||
      message.contains('already subscribed') ||
      message.contains('duplicate');
}

class _ClientSubscriptionPaywallSheet extends StatefulWidget {
  const _ClientSubscriptionPaywallSheet({
    required this.userId,
    required this.parentContext,
    required this.service,
  });

  final String userId;
  final BuildContext parentContext;
  final ClientSubscriptionService service;

  @override
  State<_ClientSubscriptionPaywallSheet> createState() =>
      _ClientSubscriptionPaywallSheetState();
}

class _ClientSubscriptionPaywallSheetState
    extends State<_ClientSubscriptionPaywallSheet> {
  static const Color _paywallGreen = Color(0xFF22C55E);

  bool _isCheckingStatus = true;
  bool _isAlreadySubscribed = false;
  bool _isLoadingProduct = true;
  bool _isBusy = false;
  ProductDetails? _product;
  String? _helperMessage;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStatusAndProduct());
  }

  Future<void> _loadStatusAndProduct() async {
    final access = await widget.service._fetchBackendAccess(userId: widget.userId);
    final products = await widget.service.loadProducts();
    if (!mounted) return;
    setState(() {
      _isAlreadySubscribed = access == true;
      _isCheckingStatus = false;
      _product = products.isNotEmpty ? products.first : null;
      _isLoadingProduct = false;
    });
  }

  String _trialLabel(ProductDetails? product) {
    if (product == null) return 'Free trial available';
    final combined = '${product.title} ${product.description}'.toLowerCase();
    final match = RegExp(r'(\d+)\s*[- ]?(day|week|month)s?\s+free\s+trial')
        .firstMatch(combined);
    if (match != null) {
      final n = match.group(1);
      final unit = match.group(2);
      if (n != null && unit != null) {
        return '$n-${unit[0].toUpperCase()}${unit.substring(1)} free trial';
      }
    }
    if (combined.contains('free trial')) return 'Free trial available';
    return 'Subscribe to unlock full access';
  }

  String _ctaLabel() {
    if (_isBusy) return 'Processing...';
    if (_isAlreadySubscribed) return 'Got it';
    return _trialLabel(_product).toLowerCase().contains('free trial')
        ? 'Start Free Trial'
        : 'Subscribe';
  }

  Future<void> _handleRestore() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _helperMessage = null;
    });
    final hasSub = await widget.service.restorePurchase();
    if (!mounted) return;
    if (hasSub) {
      await widget.service.onPaywallSuccess();
      Navigator.of(context).pop();
      if (widget.parentContext.mounted) {
        showSnackbar(
          context: widget.parentContext,
          message: 'Subscription restored.',
        );
      }
      return;
    }
    setState(() {
      _isBusy = false;
      _helperMessage = 'No active subscription was found to restore.';
    });
  }

  Future<void> _handlePrimaryAction() async {
    if (_isBusy) return;
    if (_isAlreadySubscribed) {
      await widget.service.onPaywallSuccess();
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _isBusy = true;
      _helperMessage = null;
    });
    final completed = await widget.service.startPurchase(
      context: context,
      userId: widget.userId,
      product: _product,
    );
    if (!mounted) return;
    if (completed) {
      await widget.service.onPaywallSuccess();
      Navigator.of(context).pop();
      if (widget.parentContext.mounted) {
        showSnackbar(
          context: widget.parentContext,
          message: 'Subscription activated.',
        );
      }
      return;
    }
    setState(() => _isBusy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final product = _product;
    final trialLabel = _trialLabel(product);

    return Container(
      decoration: BoxDecoration(gradient: themeGradient(context: context)),
      child: SafeArea(
        top: true,
        bottom: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.34,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'images/background.jpg',
                      fit: BoxFit.cover,
                      alignment: Alignment.center,
                    ),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.12),
                            Colors.black.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 16,
                      child: GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.close,
                              color: Colors.white, size: 20),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start your coaching journey today',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _isAlreadySubscribed
                                ? 'You are already subscribed.'
                                : trialLabel,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_isCheckingStatus)
                      Row(
                        children: [
                          const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 10),
                          Text('Checking subscription status...',
                              style: theme.textTheme.bodyMedium),
                        ],
                      )
                    else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product?.title.trim().isNotEmpty == true
                                      ? product!.title
                                      : 'Not Athletes Pro',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  product?.price ?? 'Price unavailable',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (!_isAlreadySubscribed) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Billed through Apple subscription',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color:
                                          (isDark ? Colors.white : Colors.black)
                                              .withValues(alpha: 0.64),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _paywallGreen,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(Icons.check,
                                color: Colors.white, size: 16),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    if (_helperMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(_helperMessage!,
                            style: theme.textTheme.bodySmall),
                      ),
                    if (!_isAlreadySubscribed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: TextButton(
                          onPressed: _isBusy ? null : _handleRestore,
                          child: const Text('Restore purchase'),
                        ),
                      ),
                    if (_isLoadingProduct && !_isAlreadySubscribed)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Loading plan details...',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: OpacityButtonWidgetTwo(
                        onPressed: (_isBusy ||
                                (_product == null && !_isAlreadySubscribed))
                            ? null
                            : _handlePrimaryAction,
                        label: _ctaLabel(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        children: [
                          Text(
                            'By continuing, you agree to our ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => openUrl(
                                url: _privacyPolicyUrl, context: context),
                            child: Text(
                              'Privacy Policy',
                              style: theme.textTheme.bodySmall?.copyWith(
                                decoration: TextDecoration.underline,
                                color: _paywallGreen,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
