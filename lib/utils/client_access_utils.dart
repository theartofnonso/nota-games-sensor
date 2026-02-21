import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_flavor.dart';
import '../services/iap_service.dart';
import '../shared_prefs.dart';
import '../utils/dialog_utils.dart';
import '../utils/general_utils.dart';
import '../utils/uri_utils.dart';
import '../urls.dart';
import '../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../widgets/buttons/opacity_button_widget_two.dart';

const Duration _subscriptionRefreshInterval = Duration(minutes: 20);
const String _privacyPolicyUrl = 'https://www.notathletes.com/privacy';

enum ClientFeatureGate {
  startWorkoutSession,
  resumeWorkoutSession,
  logMeal,
  generic,
}

String _defaultBlockedMessageForFeature(ClientFeatureGate feature) {
  switch (feature) {
    case ClientFeatureGate.startWorkoutSession:
      return 'You need an active subscription to start a workout session.';
    case ClientFeatureGate.resumeWorkoutSession:
      return 'You need an active subscription to resume workout sessions.';
    case ClientFeatureGate.logMeal:
      return 'You need an active subscription to log meals and nutrition.';
    case ClientFeatureGate.generic:
      return 'You need an active subscription to use this feature.';
  }
}

class ClientSubscriptionSnapshot {
  final bool access;
  final DateTime lastSyncedAt;

  const ClientSubscriptionSnapshot({
    required this.access,
    required this.lastSyncedAt,
  });

  bool isStale({Duration maxAge = _subscriptionRefreshInterval}) {
    return DateTime.now().difference(lastSyncedAt) > maxAge;
  }

  Map<String, dynamic> toJson() => {
        'access': access,
        'last_synced_at': lastSyncedAt.toIso8601String(),
      };

  factory ClientSubscriptionSnapshot.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      final raw = value?.toString().trim();
      if (raw == null || raw.isEmpty) return null;
      return DateTime.tryParse(raw);
    }

    final lastSyncedAt = parseDate(json['last_synced_at']) ?? DateTime.now();

    return ClientSubscriptionSnapshot(
      access: json['access'] == true,
      lastSyncedAt: lastSyncedAt,
    );
  }
}

ClientSubscriptionSnapshot? getLocalClientSubscriptionSnapshot() {
  try {
    final raw = SharedPrefs().subscriptionEntitlementSnapshot.trim();
    if (raw.isEmpty) return null;
    final data = jsonDecode(raw);
    if (data is! Map<String, dynamic>) return null;
    return ClientSubscriptionSnapshot.fromJson(data);
  } catch (_) {
    return null;
  }
}

void _saveLocalClientSubscriptionSnapshot(ClientSubscriptionSnapshot snapshot) {
  SharedPrefs().subscriptionEntitlementSnapshot = jsonEncode(snapshot.toJson());
}

void clearLocalClientSubscriptionSnapshot() {
  SharedPrefs().subscriptionEntitlementSnapshot = '';
}

void _setTemporaryLocalAccess({required bool access}) {
  final snapshot = ClientSubscriptionSnapshot(
    access: access,
    lastSyncedAt: DateTime.now(),
  );
  _saveLocalClientSubscriptionSnapshot(snapshot);
}

Future<void> refreshClientSubscriptionSnapshotInBackground({
  bool force = false,
}) async {
  if (!AppConfig.isClient) return;
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null || user.id.trim().isEmpty) return;

  final current = getLocalClientSubscriptionSnapshot();
  if (!force && current != null && !current.isStale()) return;

  final latest = await _fetchBackendSubscriptionSnapshot(userId: user.id);
  if (latest != null) {
    _saveLocalClientSubscriptionSnapshot(latest);
  }
}

Future<bool> ensureClientSubscriptionAccess({
  required BuildContext context,
  String blockedMessage =
      'You need an active subscription to use this feature.',
}) async {
  if (!AppConfig.isClient) return true;

  final local = getLocalClientSubscriptionSnapshot();
  if (local?.access == true) {
    unawaited(refreshClientSubscriptionSnapshotInBackground());
    return true;
  }

  final user = Supabase.instance.client.auth.currentUser;
  if (user != null && user.id.trim().isNotEmpty) {
    final refreshed = await _fetchBackendSubscriptionSnapshot(userId: user.id);
    if (refreshed != null) {
      _saveLocalClientSubscriptionSnapshot(refreshed);
      if (refreshed.access) return true;
    }
  }

  if (!context.mounted) return false;
  showSnackbar(context: context, message: blockedMessage);
  await showClientSubscriptionSheet(context: context);
  return false;
}

Future<bool> guardClientFeature({
  required BuildContext context,
  required ClientFeatureGate feature,
  String? blockedMessage,
}) {
  return ensureClientSubscriptionAccess(
    context: context,
    blockedMessage: blockedMessage ?? _defaultBlockedMessageForFeature(feature),
  );
}

Future<void> showClientSubscriptionSheet({
  required BuildContext context,
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

  await showAppBottomSheet<void>(
    context: context,
    isDraggable: false,
    isScrollControlled: true,
    isDismissible: true,
    child: _ClientSubscriptionPaywallScreen(
      userId: user.id,
      parentContext: context,
    ),
  );
}

Future<ClientSubscriptionSnapshot?> _fetchBackendSubscriptionSnapshot({
  required String userId,
}) async {
  try {
    final uri = Uri.parse(apiNotathletesBaseUrl).resolve(subscriptionStatusPath);
    final response = await http.get(
      uri.replace(queryParameters: {'user_id': userId}),
      headers: {'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) return null;

    final snapshot = ClientSubscriptionSnapshot(
      access: data['access'] == true,
      lastSyncedAt: DateTime.now(),
    );
    return snapshot;
  } catch (_) {
    return null;
  }
}

/// Loads the subscription product, starts the Apple purchase flow directly,
/// and waits for the result. No custom sheet—Apple's native UI is shown immediately.
Future<bool> _startIapPurchase({
  required BuildContext context,
  String? applicationUserName,
  ProductDetails? productOverride,
}) async {
  final service = iapService;
  final products = productOverride == null ? await service.loadProducts() : null;
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

class _ClientSubscriptionPaywallScreen extends StatefulWidget {
  final String userId;
  final BuildContext parentContext;

  const _ClientSubscriptionPaywallScreen({
    required this.userId,
    required this.parentContext,
  });

  @override
  State<_ClientSubscriptionPaywallScreen> createState() =>
      _ClientSubscriptionPaywallScreenState();
}

class _ClientSubscriptionPaywallScreenState
    extends State<_ClientSubscriptionPaywallScreen> {
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
    final futures = await Future.wait([
      _fetchBackendSubscriptionSnapshot(userId: widget.userId),
      iapService.loadProducts(),
    ]);
    final snapshot = futures[0] as ClientSubscriptionSnapshot?;
    final products = futures[1] as List<ProductDetails>;
    if (!mounted) return;
    if (snapshot != null) {
      _saveLocalClientSubscriptionSnapshot(snapshot);
    }
    setState(() {
      _isAlreadySubscribed = snapshot?.access ?? false;
      _isCheckingStatus = false;
      _product = products.isNotEmpty ? products.first : null;
      _isLoadingProduct = false;
    });
  }

  String _trialLabel(ProductDetails? product) {
    if (product == null) return 'Free trial available';
    final combined = '${product.title} ${product.description}'.toLowerCase();
    final regex =
        RegExp(r'(\d+)\s*[- ]?(day|week|month)s?\s+free\s+trial', caseSensitive: false);
    final match = regex.firstMatch(combined);
    if (match != null) {
      final count = match.group(1);
      final unit = match.group(2);
      if (count != null && unit != null) {
        return '$count-${unit[0].toUpperCase()}${unit.substring(1)} free trial';
      }
    }
    if (combined.contains('free trial')) {
      return 'Free trial available';
    }
    return 'Subscribe to unlock full access';
  }

  String _ctaLabel() {
    if (_isBusy) return 'Processing...';
    if (_isAlreadySubscribed) return 'Got it';
    final trial = _trialLabel(_product).toLowerCase();
    if (trial.contains('free trial')) return 'Start Free Trial';
    return 'Subscribe';
  }

  Future<void> _handleRestore() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _helperMessage = null;
    });
    final hasSub = await iapService.checkHasActiveSubscription();
    if (!mounted) return;
    if (hasSub) {
      _setTemporaryLocalAccess(access: true);
      unawaited(refreshClientSubscriptionSnapshotInBackground(force: true));
      Navigator.of(context).pop();
      if (widget.parentContext.mounted) {
        showSnackbar(
          context: widget.parentContext,
          message: 'Subscription restored successfully.',
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
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _isBusy = true;
      _helperMessage = null;
    });
    final purchaseCompleted = await _startIapPurchase(
      context: context,
      applicationUserName: widget.userId,
      productOverride: _product,
    );
    if (!mounted) return;
    if (purchaseCompleted) {
      _setTemporaryLocalAccess(access: true);
      unawaited(refreshClientSubscriptionSnapshotInBackground(force: true));
      Navigator.of(context).pop();
      if (widget.parentContext.mounted) {
        showSnackbar(
          context: widget.parentContext,
          message: 'Subscription purchase completed.',
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
                    Image.asset('images/background.jpg', fit: BoxFit.cover),
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
                          child: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 20,
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
                  mainAxisSize: MainAxisSize.min,
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
                                      color: (isDark ? Colors.white : Colors.black)
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
                            child: const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    if (_helperMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _helperMessage!,
                          style: theme.textTheme.bodySmall,
                        ),
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
                        onPressed:
                            (_isBusy || (_product == null && !_isAlreadySubscribed))
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
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => openUrl(
                              url: _privacyPolicyUrl,
                              context: context,
                            ),
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

