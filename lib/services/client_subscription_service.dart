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

final _subscriptionLogger = getLogger(className: 'ClientSubscriptionService');

class ClientSubscriptionService {
  ClientSubscriptionService._();
  static final ClientSubscriptionService instance =
      ClientSubscriptionService._();

  /// Bumps when [hasAccess] may have changed (UI: nav, home card, router redirect).
  final ValueNotifier<int> accessRevision = ValueNotifier<int>(0);

  void _bumpAccessRevision() {
    accessRevision.value++;
  }

  /// In-memory cache of subscription status. Null = not yet checked.
  /// True only when **app_access** and **coach_access** are both active.
  bool? _cachedAccess;

  /// Shared future for in-flight refresh. Prevents duplicate fetches when
  /// app-load refresh and first gate check overlap.
  Future<void>? _refreshInProgress;

  /// Loads subscription access from RevenueCat ([Purchases.getCustomerInfo])
  /// and updates in-memory cache (requires **app_access** + **coach_access**).
  Future<void> refreshSubscriptionStatus() async {
    if (!AppConfig.isClient) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null || user.id.trim().isEmpty) {
      _cachedAccess = null;
      _refreshInProgress = null;
      _bumpAccessRevision();
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
  /// Client access requires **app_access** and **coach_access** (see `subscription_catalog.dart`).
  Future<bool> syncAccessFromRevenueCat() async {
    if (!RevenueCatBootstrap.isConfigured) {
      _cachedAccess = false;
      _bumpAccessRevision();
      return false;
    }
    try {
      final info = await Purchases.getCustomerInfo();
      final access =
          RevenueCatSubscriptionHelpers.hasCoachLedSubscription(info);
      _cachedAccess = access;
      _bumpAccessRevision();
      return access;
    } catch (e, st) {
      _subscriptionLogger.w(
        'RevenueCat getCustomerInfo failed',
        error: e,
        stackTrace: st,
      );
      _cachedAccess = false;
      _bumpAccessRevision();
      return false;
    }
  }

  /// Clears cached status (e.g. on logout).
  void clearCachedAccess() {
    _cachedAccess = null;
    _refreshInProgress = null;
    _bumpAccessRevision();
  }

  /// Whether the client has active coach-led subscription (both entitlements).
  bool get hasAccess => _cachedAccess == true;

  /// Same as [hasAccess] for clients (cache is only true when **coach_access** is active).
  bool get hasCoachAccess => hasAccess;

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

  /// Called by paywall when purchase/restore succeeds or when user dismisses as subscribed.
  ///
  /// When [notifyCoach] is true (new purchase or restore), posts to
  /// [notifyClientAssignedPath] so the coach can be notified.
  Future<void> onPaywallSuccess({bool notifyCoach = false}) async {
    await refreshSubscriptionStatus();
    if (notifyCoach && AppConfig.isClient) {
      unawaited(_notifyCoachClientSubscribed());
    }
  }

  /// POST [fcmNotathletesBaseUrl]/[notifyClientAssignedPath] with Supabase JWT.
  Future<void> _notifyCoachClientSubscribed() async {
    if (!AppConfig.isClient) return;
    final auth = Supabase.instance.client.auth;
    final session = auth.currentSession;
    final user = auth.currentUser;
    if (session == null || user == null) return;
    final userId = user.id.trim();
    final token = session.accessToken.trim();
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
        _subscriptionLogger.w(
          'notify-client-assigned HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e, st) {
      _subscriptionLogger.w(
        'notify-client-assigned failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Pushes the paywall as a **full-screen** route (fade), not a bottom sheet.
  ///
  /// Pass [assignedCoach] when already loaded (e.g. from [ClientSubscribePromptCard])
  /// so the UI can render immediately.
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

  /// Presents the paywall when coach-led subscription (both entitlements) is not active.
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
      _subscriptionLogger.w(
        'presentPaywallIfAppAccessMissing failed',
        error: e,
        stackTrace: st,
      );
    }
  }

}
