import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_flavor.dart';
import '../colors.dart';
import '../urls.dart';
import '../utils/notathletes_auth_headers.dart';
import '../utils/dialog_utils.dart';
import '../utils/general_utils.dart';
import '../utils/theme/color_extensions.dart';
import '../utils/uri_utils.dart';
import '../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../widgets/buttons/opacity_button_widget_two.dart';
import 'chat_bootstrap_service.dart';
import 'iap_service.dart';

const String _privacyPolicyUrl = 'https://www.notathletes.com/privacy';
const String _termsOfUseUrl =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

/// Subscription duration text inferred from product ID (e.g. notathletes_monthly → per month).
String _subscriptionDuration(String? productId) {
  if (productId == null || productId.isEmpty) return '';
  final lower = productId.toLowerCase();
  if (lower.contains('annual') ||
      lower.contains('yearly') ||
      lower.contains('_year')) {
    return 'per year, billed annually';
  }
  if (lower.contains('monthly') || lower.contains('_month')) {
    return 'per month';
  }
  if (lower.contains('weekly') || lower.contains('_week')) {
    return 'per week';
  }
  return 'billed through Apple';
}

class ClientSubscriptionService {
  ClientSubscriptionService._();
  static final ClientSubscriptionService instance =
      ClientSubscriptionService._();

  /// In-memory cache of subscription status. Null = not yet checked.
  /// Checked once at app load when user authenticates; reused at gate points.
  bool? _cachedAccess;

  /// Cached subscription type from IAP (Pro vs self-coaching). Set when we have
  /// access and have run restore to get product IDs.
  bool? _cachedIsSelfCoaching;

  /// Shared future for in-flight refresh. Prevents duplicate fetches when
  /// app-load refresh and first gate check overlap.
  Future<void>? _refreshInProgress;

  /// Fetches subscription status from backend and caches in memory.
  /// Also runs restore when access is granted to determine subscription type
  /// (Pro vs self-coaching). Non-blocking when called at app load.
  Future<void> refreshSubscriptionStatus() async {
    if (!AppConfig.isClient) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.id.trim().isEmpty) {
      _cachedAccess = null;
      _cachedIsSelfCoaching = null;
      _refreshInProgress = null;
      return;
    }

    if (_refreshInProgress != null) {
      await _refreshInProgress;
      return;
    }

    final future = _fetchBackendAccess(userId: user.id).then((access) async {
      if (access != null) _cachedAccess = access;
      if (access == true) {
        await iapService.restorePurchases();
        _cachedIsSelfCoaching = iapService.isSelfCoachingSubscription;
      } else {
        _cachedIsSelfCoaching = null;
      }
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
    _cachedIsSelfCoaching = null;
    _refreshInProgress = null;
  }

  /// Whether the client has active subscription access (from last refresh).
  bool get hasAccess => _cachedAccess == true;

  /// True if user has self-coaching subscription (Not Athletes). Creates own
  /// routines, nutrition template; skips coach selection. Defaults to false
  /// when unknown.
  bool get isSelfCoaching => _cachedIsSelfCoaching == true;

  /// Whether the cache has been populated (by startup or a prior refresh).
  bool get isCachePopulated => _cachedAccess != null;

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

  /// Returns the blocking paywall widget for the subscription gate.
  /// No close button; on success calls [onComplete].
  Widget buildBlockingPaywall({required VoidCallback onComplete}) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.id.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return _ClientSubscriptionPaywallSheet(
      userId: user.id,
      parentContext: null,
      service: this,
      showCloseButton: false,
      onBlockingComplete: onComplete,
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
      final response = await http
          .get(
            uri.replace(queryParameters: {'user_id': userId}),
            headers: notathletesAuthHeaders(),
          )
          .timeout(const Duration(seconds: 15));
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
    this.showCloseButton = true,
    this.onBlockingComplete,
  });

  final String userId;
  final BuildContext? parentContext;
  final ClientSubscriptionService service;
  final bool showCloseButton;
  final VoidCallback? onBlockingComplete;

  @override
  State<_ClientSubscriptionPaywallSheet> createState() =>
      _ClientSubscriptionPaywallSheetState();
}

class _ClientSubscriptionPaywallSheetState
    extends State<_ClientSubscriptionPaywallSheet> {
  bool _isCheckingStatus = true;
  bool _isAlreadySubscribed = false;
  bool _isLoadingProduct = true;
  bool _isBusy = false;
  List<ProductDetails> _products = [];
  ProductDetails? _selectedProduct;

  @override
  void initState() {
    super.initState();
    unawaited(_loadStatusAndProduct());
  }

  Future<void> _loadStatusAndProduct() async {
    final access =
        await widget.service._fetchBackendAccess(userId: widget.userId);
    final products = await widget.service.loadProducts();
    if (!mounted) return;
    ProductDetails? defaultProduct;
    if (products.isNotEmpty) {
      if (access == true) {
        final purchasedIds = iapService.purchasedProductIds;
        final activeProduct =
            products.where((p) => purchasedIds.contains(p.id)).firstOrNull;
        defaultProduct = activeProduct ?? products.first;
      } else {
        defaultProduct = products.first;
      }
    }
    setState(() {
      _isAlreadySubscribed = access == true;
      _isCheckingStatus = false;
      _products = products;
      _selectedProduct = defaultProduct;
      _isLoadingProduct = false;
    });
  }

  String _productDisplayName(ProductDetails? product) {
    if (product == null) return 'Not Athletes Pro';
    if (product.title.trim().isNotEmpty) return product.title;
    if (product.id == iapProductIdPro) return 'Not Athletes Pro';
    if (product.id == iapProductIdSolo) return 'Not Athletes';
    return product.id;
  }

  String _productDescription(ProductDetails? product) {
    if (product == null) return '';
    if (product.id == iapProductIdPro) {
      return 'Train with a coach who builds your plans and gives you feedback.';
    }
    if (product.id == iapProductIdSolo) {
      return 'Train on your own: create and manage your own routines.';
    }
    return '';
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

  bool _isSelectedProductActive() {
    if (!_isAlreadySubscribed) return false;
    final purchasedIds = iapService.purchasedProductIds;
    return _selectedProduct != null &&
        purchasedIds.contains(_selectedProduct!.id);
  }

  String _ctaLabel() {
    if (_isBusy) return 'Processing...';
    if (_selectedProduct?.id == iapProductIdPro) {
      return 'Start training with a coach';
    }
    if (_selectedProduct?.id == iapProductIdSolo) return 'Start training alone';
    return 'Subscribe';
  }

  void _onSuccess() {
    if (widget.onBlockingComplete != null) {
      widget.onBlockingComplete!();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _handleRestore() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    final hasSub = await widget.service.restorePurchase();
    if (!mounted) return;
    if (hasSub) {
      await widget.service.onPaywallSuccess();
      _onSuccess();
      if (widget.onBlockingComplete == null &&
          widget.parentContext != null &&
          widget.parentContext!.mounted) {
        showSnackbar(
          context: widget.parentContext!,
          message: 'Subscription restored.',
        );
      }
      return;
    }
    setState(() => _isBusy = false);
    if (mounted) {
      showErrorBottomSheet(
        context: context,
        title: 'Restore purchase',
        message: 'No active subscription was found to restore.',
      );
    }
  }

  Future<void> _handlePrimaryAction() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    final completed = await widget.service.startPurchase(
      context: context,
      userId: widget.userId,
      product: _selectedProduct,
    );
    if (!mounted) return;
    if (completed) {
      await widget.service.onPaywallSuccess();
      _onSuccess();
      if (widget.onBlockingComplete == null &&
          widget.parentContext != null &&
          widget.parentContext!.mounted) {
        showSnackbar(
          context: widget.parentContext!,
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
    final accent = theme.colors.vibrantAccent;
    final selectedProduct = _selectedProduct;
    final trialLabel = _trialLabel(selectedProduct);

    return SizedBox.expand(
      child: Container(
        decoration: BoxDecoration(gradient: themeGradient(context: context)),
        child: SafeArea(
          top: false,
          bottom: true,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
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
                    if (widget.showCloseButton)
                      Positioned(
                        top: 0,
                        left: 0,
                        child: SafeArea(
                          top: true,
                          bottom: false,
                          left: true,
                          right: false,
                          minimum: const EdgeInsets.only(left: 20, top: 60),
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
                      ),
                    Positioned(
                      left: 20,
                      right: 20,
                      bottom: 16,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start your journey today',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            trialLabel,
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
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  widget.showCloseButton ? 18 : 8,
                ),
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
                    else ...[
                      if (_products.isEmpty)
                        Text(
                          'Loading plan details...',
                          style: theme.textTheme.bodyMedium,
                        )
                      else ...[
                        ..._products.map((p) {
                          final isSelected = p.id == selectedProduct?.id;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GestureDetector(
                              onTap: () => setState(() => _selectedProduct = p),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? accent.withValues(alpha: 0.2)
                                      : (isDark ? Colors.white : Colors.black)
                                          .withValues(alpha: 0.06),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _productDisplayName(p),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                          if (_productDescription(p)
                                              .isNotEmpty) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              _productDescription(p),
                                              style: theme.textTheme.bodySmall
                                                  ?.copyWith(
                                                color: (isDark
                                                        ? Colors.white
                                                        : Colors.black)
                                                    .withValues(alpha: 0.7),
                                                height: 1.3,
                                              ),
                                            ),
                                          ],
                                          const SizedBox(height: 2),
                                          Text(
                                            p.price,
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _subscriptionDuration(p.id) != ''
                                                ? _subscriptionDuration(p.id)
                                                : 'Billed through Apple subscription',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                              color: (isDark
                                                      ? Colors.white
                                                      : Colors.black)
                                                  .withValues(alpha: 0.64),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? sapphireDark80
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        border: isSelected
                                            ? null
                                            : Border.all(
                                                color: (isDark
                                                        ? Colors.white
                                                        : Colors.black)
                                                    .withValues(alpha: 0.4),
                                                width: 1.5,
                                              ),
                                      ),
                                      alignment: Alignment.center,
                                      child: isSelected
                                          ? const Icon(Icons.check,
                                              color: Colors.white, size: 16)
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ],
                    const SizedBox(height: 12),
                    if (!_isSelectedProductActive())
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: TextButton(
                          onPressed: _isBusy ? null : _handleRestore,
                          child: const Text('Restore purchase'),
                        ),
                      ),
                    if (_isLoadingProduct && !_isSelectedProductActive())
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          'Loading plan details...',
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    if (!_isSelectedProductActive())
                      SizedBox(
                        width: double.infinity,
                        child: OpacityButtonWidgetTwo(
                          onPressed: (_isBusy || _selectedProduct == null)
                              ? null
                              : _handlePrimaryAction,
                          label: _ctaLabel(),
                          buttonColor: accent,
                        ),
                      ),
                    const SizedBox(height: 16),
                    if (!_isSelectedProductActive())
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Payment will be charged to your Apple ID account at confirmation of purchase.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: (isDark ? Colors.white : Colors.black)
                                .withValues(alpha: 0.6),
                            height: 1.35,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
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
                            onTap: () =>
                                openUrl(url: _termsOfUseUrl, context: context),
                            child: Text(
                              'Terms of Use',
                              style: theme.textTheme.bodySmall?.copyWith(
                                decoration: TextDecoration.underline,
                                color: accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            ' and ',
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
                                color: accent,
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
                    if (!widget.showCloseButton) ...[
                      const SizedBox(height: 24),
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            await ChatBootstrapService.logoutAgoraChat();
                            await Supabase.instance.client.auth.signOut();
                          },
                          child: const Text('Log out'),
                        ),
                      ),
                    ],
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
