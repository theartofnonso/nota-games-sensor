import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_flavor.dart';
import '../config/revenuecat_config.dart';
import '../logger.dart';
import 'revenuecat_customer_info_listener.dart';

/// Initializes RevenueCat for the client app and ties [Purchases] to Supabase auth.
class RevenueCatBootstrap {
  RevenueCatBootstrap._();

  static final _logger = getLogger(className: 'RevenueCatBootstrap');
  static bool _configured = false;

  static bool get isConfigured => _configured;

  static Future<void> configureForClient() async {
    if (!AppConfig.isClient || _configured) return;

    final apiKey = _resolveApiKey();
    if (apiKey.isEmpty) {
      _logger.w(
        'RevenueCat API key missing; set REVENUECAT_API_KEY (test), or '
        'REVENUECAT_APPLE_API_KEY / REVENUECAT_GOOGLE_API_KEY for store builds.',
      );
      return;
    }

    await Purchases.configure(PurchasesConfiguration(apiKey));
    _configured = true;
    registerRevenueCatCustomerInfoListener();
    _logger.i('RevenueCat configured');

    final session = Supabase.instance.client.auth.currentSession;
    final uid = session?.user.id;
    if (uid != null && uid.isNotEmpty) {
      await logInUser(uid);
    }
  }

  /// Call when the Supabase session becomes available (e.g. after sign-in).
  static Future<void> logInUser(String appUserId) async {
    if (!AppConfig.isClient || !_configured || appUserId.isEmpty) return;
    try {
      await Purchases.logIn(appUserId);
    } catch (e, st) {
      _logger.w('Purchases.logIn failed', error: e, stackTrace: st);
    }
  }

  /// Call before or after Supabase sign-out; errors are ignored.
  static Future<void> logOutIfClient() async {
    if (!AppConfig.isClient || !_configured) return;
    try {
      await Purchases.logOut();
    } on PlatformException catch (e) {
      if (PurchasesErrorHelper.getErrorCode(e) ==
          PurchasesErrorCode.logOutWithAnonymousUserError) {
        return;
      }
    } catch (_) {}
  }

  static String _resolveApiKey() {
    if (Platform.isAndroid) {
      if (RevenueCatConfig.googleApiKey.isNotEmpty) {
        return RevenueCatConfig.googleApiKey;
      }
    } else {
      if (RevenueCatConfig.appleApiKey.isNotEmpty) {
        return RevenueCatConfig.appleApiKey;
      }
    }
    return RevenueCatConfig.publicSdkKey;
  }
}
