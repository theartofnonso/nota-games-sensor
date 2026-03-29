import 'package:flutter/material.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_flavor.dart';
import '../utils/dialog_utils.dart';
import '../logger.dart';
import '../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../widgets/subscription/custom_subscription_paywall.dart';
import 'revenue_cat_bootstrap.dart';
import 'revenuecat_subscription_helpers.dart';

final _subscriptionLogger = getLogger(className: 'ClientSubscriptionService');

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

  /// Loads subscription access from RevenueCat ([Purchases.getCustomerInfo])
  /// and updates in-memory cache (solo vs coach from entitlements).
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

    final future = syncAccessFromRevenueCat().then((_) {});
    _refreshInProgress = future;
    try {
      await future;
    } finally {
      _refreshInProgress = null;
    }
  }

  /// Syncs [Purchases] customer info into the service cache.
  /// Gate uses **app_access**; solo vs coach uses **coach_access** (see `subscription_catalog.dart`).
  Future<bool> syncAccessFromRevenueCat() async {
    if (!RevenueCatBootstrap.isConfigured) {
      _cachedAccess = false;
      _cachedIsSelfCoaching = null;
      return false;
    }
    try {
      final info = await Purchases.getCustomerInfo();
      final access = RevenueCatSubscriptionHelpers.hasAppAccess(info);
      _cachedAccess = access;
      _cachedIsSelfCoaching = access
          ? RevenueCatSubscriptionHelpers.isSoloTier(info)
          : null;
      return access;
    } catch (e, st) {
      _subscriptionLogger.w(
        'RevenueCat getCustomerInfo failed',
        error: e,
        stackTrace: st,
      );
      _cachedAccess = false;
      _cachedIsSelfCoaching = null;
      return false;
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

  /// True when user has **app_access** but not **coach_access** (solo / self-coaching).
  bool get isSelfCoaching => _cachedIsSelfCoaching == true;

  /// True when **coach_access** is active (from last refresh). Requires [hasAccess].
  bool get hasCoachAccess =>
      hasAccess &&
      !isSelfCoaching;

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

  /// Called by paywall when purchase or restore succeeds. Refreshes RevenueCat cache.
  Future<void> onPaywallSuccess() async {
    await refreshSubscriptionStatus();
  }

  /// Presents the custom paywall (RevenueCat offerings / packages).
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

    if (!RevenueCatBootstrap.isConfigured) {
      if (context.mounted) {
        showErrorBottomSheet(
          context: context,
          title: 'Subscription unavailable',
          message: 'Subscription purchases are not available in this build.',
        );
      }
      return;
    }

    if (!context.mounted) return;
    await showAppBottomSheet<void>(
      context: context,
      isDraggable: false,
      isScrollControlled: true,
      isDismissible: true,
      child: CustomSubscriptionPaywall(
        service: this,
        parentContext: context,
        showCloseButton: true,
      ),
    );
  }

  /// Full-screen subscription gate (custom UI; data from RevenueCat).
  Widget buildBlockingPaywall({required VoidCallback onComplete}) {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.id.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    if (!RevenueCatBootstrap.isConfigured) {
      return const _SubscriptionGateRevenueCatDisabled();
    }
    return CustomSubscriptionPaywall(
      service: this,
      showCloseButton: false,
      onBlockingComplete: onComplete,
    );
  }

  /// Presents the paywall only when **app_access** is not active.
  Future<void> presentPaywallIfAppAccessMissing({
    required BuildContext context,
  }) async {
    if (!RevenueCatBootstrap.isConfigured) return;
    try {
      final info = await Purchases.getCustomerInfo();
      if (!context.mounted) return;
      if (RevenueCatSubscriptionHelpers.hasAppAccess(info)) return;
      await showPaywall(context: context);
    } catch (e, st) {
      _subscriptionLogger.w(
        'presentPaywallIfAppAccessMissing failed',
        error: e,
        stackTrace: st,
      );
    }
  }

}

class _SubscriptionGateRevenueCatDisabled extends StatelessWidget {
  const _SubscriptionGateRevenueCatDisabled();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          'Subscriptions are not available in this build.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
