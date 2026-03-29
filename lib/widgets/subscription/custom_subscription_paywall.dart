import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../colors.dart';
import '../../services/client_subscription_service.dart';
import '../../services/subscription_purchase_service.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/general_utils.dart';
import '../../utils/theme/color_extensions.dart';
import '../../utils/uri_utils.dart';
import '../buttons/opacity_button_widget_two.dart';

const String _privacyPolicyUrl = 'https://www.notathletes.com/privacy';
const String _termsOfUseUrl =
    'https://www.apple.com/legal/internet-services/itunes/dev/stdeula/';

String _subscriptionDurationFromProductId(String? productId) {
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
  return '';
}

String _subscriptionPeriodLabel(StoreProduct product) {
  final period = product.subscriptionPeriod?.trim();
  if (period != null && period.isNotEmpty) {
    switch (period) {
      case 'P1D':
        return 'per day';
      case 'P1W':
        return 'per week';
      case 'P1M':
        return 'per month';
      case 'P2M':
        return 'per 2 months';
      case 'P3M':
        return 'per quarter';
      case 'P6M':
        return 'per 6 months';
      case 'P1Y':
        return 'per year, billed annually';
      default:
        break;
    }
  }
  final fromId = _subscriptionDurationFromProductId(product.identifier);
  if (fromId.isNotEmpty) return fromId;
  return 'Billed through your app store subscription';
}

/// Custom subscription UI; plans and copy come from RevenueCat offerings / [StoreProduct].
class CustomSubscriptionPaywall extends StatefulWidget {
  const CustomSubscriptionPaywall({
    super.key,
    required this.service,
    this.parentContext,
    this.showCloseButton = true,
    this.onBlockingComplete,
  });

  final ClientSubscriptionService service;
  final BuildContext? parentContext;
  final bool showCloseButton;
  final VoidCallback? onBlockingComplete;

  @override
  State<CustomSubscriptionPaywall> createState() =>
      _CustomSubscriptionPaywallState();
}

class _CustomSubscriptionPaywallState extends State<CustomSubscriptionPaywall> {
  bool _isCheckingStatus = true;
  bool _isAlreadySubscribed = false;
  bool _isLoadingPackages = true;
  bool _isBusy = false;
  List<Package> _packages = [];
  Package? _selectedPackage;
  Set<String> _activeStoreProductIds = {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final access = await widget.service.syncAccessFromRevenueCat();
    final packages =
        await SubscriptionPurchaseService.instance.loadOfferedPackages();
    if (!mounted) return;

    Package? defaultPackage;
    var ownedIds = <String>{};
    if (packages.isNotEmpty) {
      if (access) {
        try {
          final info = await Purchases.getCustomerInfo();
          ownedIds = info.activeSubscriptions.toSet();
        } catch (_) {}
        for (final pkg in packages) {
          if (ownedIds.contains(pkg.storeProduct.identifier)) {
            defaultPackage = pkg;
            break;
          }
        }
        defaultPackage ??= packages.first;
      } else {
        defaultPackage = packages.first;
      }
    }

    setState(() {
      _isAlreadySubscribed = access;
      _isCheckingStatus = false;
      _packages = packages;
      _selectedPackage = defaultPackage;
      _activeStoreProductIds = ownedIds;
      _isLoadingPackages = false;
    });
  }

  void _onSuccess({required String message}) {
    if (widget.onBlockingComplete != null) {
      widget.onBlockingComplete!();
    } else {
      Navigator.of(context).pop();
      final parent = widget.parentContext;
      if (parent != null && parent.mounted) {
        showSnackbar(context: parent, message: message);
      }
    }
  }

  String _productTitle(StoreProduct? p) {
    if (p == null) return 'Subscription';
    final t = p.title.trim();
    if (t.isNotEmpty) return t;
    return p.identifier;
  }

  String _productDescription(StoreProduct? p) {
    if (p == null) return '';
    return p.description.trim();
  }

  String _trialHint(StoreProduct? product) {
    if (product == null) return 'Subscribe to unlock full access';
    final combined = '${product.title} ${product.description}'.toLowerCase();
    final match = RegExp(
      r'(\d+)\s*[- ]?(day|week|month)s?\s+free\s+trial',
    ).firstMatch(combined);
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

  bool _selectionMatchesActiveSubscription() {
    if (!_isAlreadySubscribed || _selectedPackage == null) return false;
    return _activeStoreProductIds.contains(
      _selectedPackage!.storeProduct.identifier,
    );
  }

  String _ctaLabel() {
    if (_isBusy) return 'Processing...';
    return 'Subscribe';
  }

  String _renewalDisclaimerText() {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Payment will be charged to your Apple ID account at confirmation of purchase.';
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Payment will be charged to your Google Play account at confirmation of purchase.';
    }
    return 'Subscription automatically renews unless cancelled at least 24 hours before the end of the current period. Payment will be charged at confirmation of purchase.';
  }

  Future<void> _handleRestore() async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    final ok = await SubscriptionPurchaseService.instance.restorePurchases();
    if (!mounted) return;
    if (ok) {
      await widget.service.onPaywallSuccess();
      try {
        final info = await Purchases.getCustomerInfo();
        if (mounted) {
          setState(() {
            _activeStoreProductIds = info.activeSubscriptions.toSet();
            _isAlreadySubscribed = true;
          });
        }
      } catch (_) {}
      _onSuccess(message: 'Subscription restored.');
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

  Future<void> _handleSubscribe() async {
    if (_isBusy || _selectedPackage == null) return;
    setState(() => _isBusy = true);
    final outcome = await SubscriptionPurchaseService.instance.purchasePackage(
      _selectedPackage!,
    );
    if (!mounted) return;
    switch (outcome) {
      case SubscriptionPurchaseOutcome.success:
        await widget.service.onPaywallSuccess();
        try {
          final info = await Purchases.getCustomerInfo();
          if (mounted) {
            setState(() {
              _activeStoreProductIds = info.activeSubscriptions.toSet();
              _isAlreadySubscribed = true;
            });
          }
        } catch (_) {}
        _onSuccess(message: 'Subscription activated.');
        return;
      case SubscriptionPurchaseOutcome.userCancelled:
        setState(() => _isBusy = false);
        return;
      case SubscriptionPurchaseOutcome.failed:
        setState(() => _isBusy = false);
        if (mounted) {
          showErrorBottomSheet(
            context: context,
            title: 'Something went wrong',
            message: 'Please try again.',
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colors.vibrantAccent;
    final selected = _selectedPackage;
    final trialHint = _trialHint(selected?.storeProduct);

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
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 20,
                              ),
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
                            trialHint,
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
                          Text(
                            'Checking subscription status...',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      )
                    else ...[
                      if (_isLoadingPackages && _packages.isEmpty)
                        Text(
                          'Loading plan details...',
                          style: theme.textTheme.bodyMedium,
                        )
                      else if (_packages.isEmpty)
                        Text(
                          'No subscription plans are available right now. Please try again later.',
                          style: theme.textTheme.bodyMedium,
                        )
                      else
                        ..._packages.map((pkg) {
                          final p = pkg.storeProduct;
                          final isSelected =
                              pkg.identifier == selected?.identifier;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: GestureDetector(
                              onTap:
                                  () => setState(() => _selectedPackage = pkg),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color:
                                      isSelected
                                          ? accent.withValues(alpha: 0.2)
                                          : (isDark
                                                  ? Colors.white
                                                  : Colors.black)
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
                                            _productTitle(p),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.titleMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                          ),
                                          if (_productDescription(
                                            p,
                                          ).isNotEmpty) ...[
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
                                            p.priceString,
                                            style: theme.textTheme.bodyLarge
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w600,
                                                ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            _subscriptionPeriodLabel(p),
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
                                        color:
                                            isSelected
                                                ? sapphireDark80
                                                : Colors.transparent,
                                        borderRadius: BorderRadius.circular(6),
                                        border:
                                            isSelected
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
                                      child:
                                          isSelected
                                              ? const Icon(
                                                Icons.check,
                                                color: Colors.white,
                                                size: 16,
                                              )
                                              : null,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                    ],
                    const SizedBox(height: 12),
                    if (_selectionMatchesActiveSubscription()) ...[
                      if (widget.onBlockingComplete != null)
                        SizedBox(
                          width: double.infinity,
                          child: OpacityButtonWidgetTwo(
                            onPressed:
                                _isBusy
                                    ? null
                                    : () async {
                                      setState(() => _isBusy = true);
                                      await widget.service.onPaywallSuccess();
                                      if (!mounted) return;
                                      widget.onBlockingComplete!();
                                    },
                            label: 'Continue',
                            buttonColor: accent,
                          ),
                        ),
                    ] else ...[
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: TextButton(
                          onPressed: _isBusy ? null : _handleRestore,
                          child: const Text('Restore purchase'),
                        ),
                      ),
                      if (_isLoadingPackages && _packages.isEmpty)
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
                          onPressed:
                              (_isBusy || _selectedPackage == null)
                                  ? null
                                  : _handleSubscribe,
                          label: _ctaLabel(),
                          buttonColor: accent,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _renewalDisclaimerText(),
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
                              onTap:
                                  () => openUrl(
                                    url: _termsOfUseUrl,
                                    context: context,
                                  ),
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
                              onTap:
                                  () => openUrl(
                                    url: _privacyPolicyUrl,
                                    context: context,
                                  ),
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
