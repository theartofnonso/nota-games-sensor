import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_flavor.dart';
import '../dtos/coach_dto.dart';
import '../urls.dart';
import '../utils/dialog_utils.dart';
import '../logger.dart';
import '../widgets/subscription/custom_subscription_paywall.dart';
import 'revenue_cat_bootstrap.dart';
import 'revenuecat_subscription_helpers.dart';

final _log = getLogger(className: 'ClientSubscriptionService');

/// Client subscription gate: caches whether RevenueCat reports active **app_access**
/// and **coach_access** ([hasCoachLedSubscription]).
class ClientSubscriptionService {
  ClientSubscriptionService._();
  static final ClientSubscriptionService instance = ClientSubscriptionService._();

  /// Notifies listeners when [hasAccess] may have changed.
  final ValueNotifier<int> accessRevision = ValueNotifier<int>(0);

  bool? _cachedAccess;
  Future<void>? _refreshInProgress;

  void _bump() => accessRevision.value++;

  /// Apply SDK [CustomerInfo] directly (e.g. from [Purchases.purchase]) before cache catches up.
  void applyCustomerInfo(CustomerInfo info) {
    if (!AppConfig.isClient) return;
    _cachedAccess = RevenueCatSubscriptionHelpers.hasCoachLedSubscription(info);
    _bump();
  }

  Future<void> refreshSubscriptionStatus() async {
    if (!AppConfig.isClient) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.id.trim().isEmpty) {
      _cachedAccess = null;
      _refreshInProgress = null;
      _bump();
      return;
    }

    if (_refreshInProgress != null) await _refreshInProgress;

    final future = syncAccessFromRevenueCat().then((_) {});
    _refreshInProgress = future;
    try {
      await future;
    } finally {
      _refreshInProgress = null;
    }
  }

  Future<bool> syncAccessFromRevenueCat() async {
    if (!RevenueCatBootstrap.isConfigured) {
      _cachedAccess = false;
      _bump();
      return false;
    }
    try {
      final info = await Purchases.getCustomerInfo();
      final access = RevenueCatSubscriptionHelpers.hasCoachLedSubscription(info);
      _cachedAccess = access;
      _bump();
      return access;
    } catch (e, st) {
      _log.w('RevenueCat getCustomerInfo failed', error: e, stackTrace: st);
      _cachedAccess = false;
      _bump();
      return false;
    }
  }

  void clearCachedAccess() {
    _cachedAccess = null;
    _refreshInProgress = null;
    _bump();
  }

  bool get hasAccess => _cachedAccess == true;

  bool get isCachePopulated => _cachedAccess != null;

  /// Uses cache only; if not subscribed, shows snackbar and paywall (no refresh here).
  Future<bool> ensureAccess({
    required BuildContext context,
    required String blockedMessage,
  }) async {
    if (!AppConfig.isClient) return true;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.id.trim().isEmpty) return false;
    if (_cachedAccess == true) return true;
    if (!context.mounted) return false;

    showSnackbar(context: context, message: blockedMessage);
    await showPaywall(context: context);
    return false;
  }

  /// After purchase / restore / “Done” on paywall. [freshCustomerInfo] avoids stale reads.
  Future<void> onPaywallSuccess({
    bool notifyCoach = false,
    CustomerInfo? freshCustomerInfo,
  }) async {
    if (freshCustomerInfo != null) applyCustomerInfo(freshCustomerInfo);
    await _syncPurchasesBestEffort();
    await refreshSubscriptionStatus();
    if (notifyCoach && AppConfig.isClient) {
      unawaited(_notifyCoachClientSubscribed());
    }
  }

  Future<void> _syncPurchasesBestEffort() async {
    if (!RevenueCatBootstrap.isConfigured) return;
    try {
      await Purchases.syncPurchases();
    } catch (e, st) {
      _log.w('RevenueCat syncPurchases failed', error: e, stackTrace: st);
    }
  }

  Future<void> _notifyCoachClientSubscribed() async {
    if (!AppConfig.isClient) return;
    final session = Supabase.instance.client.auth.currentSession;
    final userId = session?.user.id.trim() ?? '';
    final token = session?.accessToken.trim() ?? '';
    if (userId.isEmpty || token.isEmpty) return;

    final uri = Uri.parse(fcmNotathletesBaseUrl).resolve(notifyClientAssignedPath);
    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'userId': userId}),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _log.w(
          'notify-client-assigned HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e, st) {
      _log.w('notify-client-assigned failed', error: e, stackTrace: st);
    }
  }

  /// Full-screen paywall route. [assignedCoach] skips refetch when already known.
  Future<void> showPaywall({
    required BuildContext context,
    CoachDto? assignedCoach,
  }) async {
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

    final parentContext = context;
    await Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: 'subscription_paywall'),
        opaque: true,
        fullscreenDialog: true,
        barrierDismissible: false,
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        pageBuilder: (modalContext, animation, secondaryAnimation) {
          return CustomSubscriptionPaywall(
            service: this,
            parentContext: parentContext,
            showCloseButton: true,
            assignedCoach: assignedCoach,
          );
        },
        transitionsBuilder: (modalContext, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeOut,
              reverseCurve: Curves.easeIn,
            ),
            child: child,
          );
        },
      ),
    );
  }

  /// Fetches customer info; shows paywall if coach-led entitlements are not active.
  Future<void> presentPaywallIfAppAccessMissing({
    required BuildContext context,
  }) async {
    if (!RevenueCatBootstrap.isConfigured) return;
    try {
      final info = await Purchases.getCustomerInfo();
      if (!context.mounted) return;
      if (RevenueCatSubscriptionHelpers.hasCoachLedSubscription(info)) return;
      await showPaywall(context: context);
    } catch (e, st) {
      _log.w('presentPaywallIfAppAccessMissing failed', error: e, stackTrace: st);
    }
  }
}
