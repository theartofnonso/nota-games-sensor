import 'dart:io' show Platform;

import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:trainware/app_flavor.dart';

bool _tokenRefreshListenerAdded = false;

/// Expected iOS bundle ID for current flavor (must match Xcode scheme + APNs topic).
String _expectedBundleId() =>
    AppConfig.isCoach ? 'com.notathletes.coach' : 'com.notathletes.client';

/// Agora APNs cert name for current flavor + build (dev = sandbox, prod = production).
String _agoraCertName() {
  final flavorSuffix = AppConfig.isCoach ? 'coach' : 'client';
  final envSuffix = kDebugMode ? 'dev' : 'prod';
  return '160658273085-$flavorSuffix-$envSuffix';
}

/// Upload APNs device token to Agora (iOS only). Required for push on iOS.
Future<void> _uploadAPNsTokenToAgora() async {
  if (ChatClient.getInstance.currentUserId == null) return;

  final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
  if (apnsToken == null) {
    debugPrint('[Push] APNs token is null');
    return;
  }

  debugPrint('[Push] APNs token: $apnsToken');
  try {
    await ChatClient.getInstance.pushManager.updateAPNsDeviceToken(apnsToken);
    debugPrint('[Push] APNs token uploaded to Agora');
  } catch (e) {
    debugPrint('[Push] Error uploading APNs token: $e');
  }
}

/// Upload FCM token to Agora (Android only). On iOS, Agora uses APNs token.
Future<void> _uploadFCMTokenToAgora(String fcmToken) async {
  if (ChatClient.getInstance.currentUserId == null) return;

  try {
    await ChatClient.getInstance.pushManager.updateFCMPushToken(fcmToken);
    debugPrint('[Push] FCM token uploaded to Agora');
  } catch (e) {
    debugPrint('[Push] Error uploading FCM token: $e');
  }
}

/// Call this **only** after user has successfully logged in to Agora Chat SDK
/// (i.e., after `ChatClient.getInstance.login` / `loginWithToken` completes).
/// Token upload requires a logged-in user; calling earlier will fail (e.g. 201).
///
/// **iOS**: Uploads APNs device token (required). Agora does not use FCM for iOS push.
/// **Android**: Uploads FCM token.
Future<void> setupPushToken() async {
  if (ChatClient.getInstance.currentUserId == null) {
    debugPrint(
        '[Push] User not logged in; skipping. Call only after Agora login.');
    return;
  }

  await FirebaseMessaging.instance.requestPermission();

  if (Platform.isIOS) {
    // iOS: Agora needs APNs token, not FCM. BadDeviceToken = wrong token type.
    final flavor = AppConfig.isCoach ? 'coach' : 'client';
    debugPrint('[Push] Flavor: $flavor');
    debugPrint('[Push] Bundle ID (expected): ${_expectedBundleId()}');
    debugPrint(
        '[Push] Build: ${kDebugMode ? "Debug (Sandbox)" : "Release (Production)"}');
    debugPrint('[Push] Agora APNs cert: ${_agoraCertName()}');

    await _uploadAPNsTokenToAgora();

    if (!_tokenRefreshListenerAdded) {
      _tokenRefreshListenerAdded = true;
      FirebaseMessaging.instance.onTokenRefresh.listen((_) async {
        if (ChatClient.getInstance.currentUserId == null) return;
        debugPrint('[Push] Token refresh (iOS): re-uploading APNs token');
        await _uploadAPNsTokenToAgora();
      });
    }
    return;
  }

  // Android: FCM token only
  final fcmToken = await FirebaseMessaging.instance.getToken();
  if (fcmToken == null) {
    debugPrint('[Push] FCM token is null');
    return;
  }
  debugPrint('[Push] Device token (FCM): $fcmToken');
  await _uploadFCMTokenToAgora(fcmToken);

  if (!_tokenRefreshListenerAdded) {
    _tokenRefreshListenerAdded = true;
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint('[Push] FCM token refreshed: $newToken');
      if (ChatClient.getInstance.currentUserId == null) return;
      await _uploadFCMTokenToAgora(newToken);
    });
  }
}
