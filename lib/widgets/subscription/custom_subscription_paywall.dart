import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../colors.dart';
import '../../dtos/coach_dto.dart';
import '../../services/assigned_coach_service.dart';
import '../../services/client_subscription_service.dart';
import '../../utils/assigned_coach_utils.dart';
import '../../services/subscription_purchase_service.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/general_utils.dart';
import '../../utils/theme/color_extensions.dart';
import '../../utils/uri_utils.dart';
import '../buttons/opacity_button_widget_two.dart';
import 'paywall_coach_showcase_card.dart';

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

/// Which [Package] should be pre-selected when the paywall loads.
///
/// - **Single package** (current backend): always that package so the CTA is
///   enabled and the row shows selected without a tap.
/// - **Multiple packages** (future): if the user already has an active
///   subscription, prefer the matching store product; otherwise [packages.first]
///   (sorted order from [SubscriptionPurchaseService.loadOfferedPackages]).
Package? _initialSelectedPackage({
  required List<Package> packages,
  required bool hasActiveSubscription,
  required Set<String> activeStoreProductIds,
}) {
  if (packages.isEmpty) return null;
  if (packages.length == 1) return packages.first;
  if (hasActiveSubscription) {
    for (final pkg in packages) {
      if (activeStoreProductIds.contains(pkg.storeProduct.identifier)) {
        return pkg;
      }
    }
  }
  return packages.first;
}

/// Full-screen subscription UI (pushed as a route — not a bottom sheet).
/// Plans and copy come from RevenueCat offerings / [StoreProduct].
class CustomSubscriptionPaywall extends StatefulWidget {
  const CustomSubscriptionPaywall({
    super.key,
    required this.service,
    this.parentContext,
    this.showCloseButton = true,
    this.onBlockingComplete,
    this.assignedCoach,
  });

  final ClientSubscriptionService service;
  final BuildContext? parentContext;
  final bool showCloseButton;
  final VoidCallback? onBlockingComplete;

  /// When set (e.g. from [ClientSubscribePromptCard]), avoids waiting on a refetch.
  final CoachDto? assignedCoach;

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
  CoachDto? _assignedCoach;

  @override
  void initState() {
    super.initState();
    _assignedCoach = widget.assignedCoach;
    unawaited(_load());
  }

  Future<void> _load() async {
    final coach =
        widget.assignedCoach ??
        AssignedCoachService.instance.profile ??
        await fetchAssignedCoachProfile();
    final access = await widget.service.syncAccessFromRevenueCat();
    final packages =
        await SubscriptionPurchaseService.instance.loadOfferedPackages();
    if (!mounted) return;

    var ownedIds = <String>{};
    if (access) {
      try {
        final info = await Purchases.getCustomerInfo();
        ownedIds = info.activeSubscriptions.toSet();
      } catch (_) {}
    }
    final defaultPackage = _initialSelectedPackage(
      packages: packages,
      hasActiveSubscription: access,
      activeStoreProductIds: ownedIds,
    );

    AssignedCoachService.instance.adoptIfEmpty(coach);
    setState(() {
      _assignedCoach = coach;
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
      Navigator.of(context, rootNavigator: true).pop();
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

  /// Trial wording from the store listing when present; empty otherwise.
  String _trialHint(StoreProduct? product) {
    if (product == null) return '';
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
    return '';
  }

  bool _selectionMatchesActiveSubscription() {
    if (!_isAlreadySubscribed || _selectedPackage == null) return false;
    return _activeStoreProductIds.contains(
      _selectedPackage!.storeProduct.identifier,
    );
  }

  String _ctaLabel() {
    if (_isBusy) return 'Processing...';
    final n = _assignedCoach?.name.trim();
    if (n != null && n.isNotEmpty) return 'Train with $n';
    return 'Train with your coach';
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
      await widget.service.onPaywallSuccess(notifyCoach: true);
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
        await widget.service.onPaywallSuccess(notifyCoach: true);
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

    // [PageRouteBuilder] does not insert Material; [IconButton], [TextButton], etc. need it.
    return Material(
      type: MaterialType.transparency,
      child: SizedBox.expand(
        child: Container(
          decoration: BoxDecoration(gradient: themeGradient(context: context)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              SafeArea(
                top: false,
                bottom: true,
                left: true,
                right: true,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  slivers: [
                    SliverToBoxAdapter(
                      child: PaywallCoachShowcaseCard(
                        coach: _assignedCoach,
                        height: 520,
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                        child: _subscriptionCardContent(context, theme),
                      ),
                    ),
                  ],
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
                    minimum: const EdgeInsets.only(left: 16, top: 8),
                    child: IconButton(
                      onPressed:
                          () =>
                              Navigator.of(
                                context,
                                rootNavigator: true,
                              ).maybePop(),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withValues(alpha: 0.45),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(8),
                        minimumSize: const Size(40, 40),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.close, size: 22),
                      tooltip: 'Close',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subscriptionCardContent(BuildContext context, ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;
    final accent = theme.colors.vibrantAccent;
    final selected = _selectedPackage;
    final trialHint = _trialHint(selected?.storeProduct);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_isCheckingStatus && trialHint.isNotEmpty) ...[
          Text(
            trialHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
        ],
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
            Text('Loading plan details...', style: theme.textTheme.bodyMedium)
          else if (_packages.isEmpty)
            Text(
              'No subscription plans are available right now. Please try again later.',
              style: theme.textTheme.bodyMedium,
            )
          else
            ..._packages.map((pkg) {
              final p = pkg.storeProduct;
              final isSelected = pkg.identifier == selected?.identifier;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedPackage = pkg),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          isSelected
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
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _productTitle(p),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_productDescription(p).isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _productDescription(p),
                                  style: theme.textTheme.bodySmall?.copyWith(
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
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _subscriptionPeriodLabel(p),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: (isDark ? Colors.white : Colors.black)
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
        const SizedBox(height: 8),
        if (_selectionMatchesActiveSubscription()) ...[
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
                        if (widget.onBlockingComplete != null) {
                          widget.onBlockingComplete!();
                        } else if (context.mounted) {
                          Navigator.of(context, rootNavigator: true)
                              .maybePop();
                        }
                      },
              label:
                  widget.onBlockingComplete != null ? 'Continue' : 'Done',
              buttonColor: accent,
            ),
          ),
        ] else ...[
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
          Align(
            alignment: Alignment.center,
            child: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: _isBusy ? null : _handleRestore,
              child: const Text('Restore purchase'),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              _renewalDisclaimerText(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: (isDark ? Colors.white : Colors.black).withValues(
                  alpha: 0.6,
                ),
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
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => openUrl(url: _termsOfUseUrl, context: context),
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
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap:
                      () => openUrl(url: _privacyPolicyUrl, context: context),
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
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
