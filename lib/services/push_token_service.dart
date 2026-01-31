import 'dart:io' show Platform;

import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

bool _androidTokenRefreshListenerAdded = false;

// ---------------------------------------------------------------------------
// Permission (both platforms)
// ---------------------------------------------------------------------------

/// Returns true if notification permission is granted.
Future<bool> isNotificationPermissionGranted() async {
  final settings = await FirebaseMessaging.instance.getNotificationSettings();
  return settings.authorizationStatus == AuthorizationStatus.authorized ||
      settings.authorizationStatus == AuthorizationStatus.provisional;
}

/// Request notification permission. Show a bottom sheet with explanation first;
/// the CTA in that sheet should call this.
Future<void> requestNotificationPermission() async {
  await FirebaseMessaging.instance.requestPermission();
}

// ---------------------------------------------------------------------------
// Token setup: call after user has logged in to Agora Chat.
// ---------------------------------------------------------------------------

/// Register push token with Agora. Call only after [ChatClient] login.
///
/// **Android:** Get FCM token → upload to Agora → listen for token refresh.
/// **iOS:** Nothing. APNs token is passed to Agora in native AppDelegate.
Future<void> setupPushToken() async {
  if (ChatClient.getInstance.currentUserId == null) {
    debugPrint('[Push] Not logged in to Agora; skip token setup.');
    return;
  }

  if (Platform.isIOS) {
    // iOS: APNs token is registered in AppDelegate (didRegisterForRemoteNotificationsWithDeviceToken).
    return;
  }

  if (Platform.isAndroid) {
    await _setupAndroidPushToken();
  }
}

// ---------------------------------------------------------------------------
// Android: FCM token → Agora
// ---------------------------------------------------------------------------

Future<void> _setupAndroidPushToken() async {
  final fcmToken = await FirebaseMessaging.instance.getToken();
  if (fcmToken == null) {
    debugPrint('[Push] Android: FCM token is null');
    return;
  }
  debugPrint('[Push] Android: FCM token obtained');
  await _uploadFCMTokenToAgora(fcmToken);

  if (!_androidTokenRefreshListenerAdded) {
    _androidTokenRefreshListenerAdded = true;
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      debugPrint('[Push] Android: FCM token refreshed');
      if (ChatClient.getInstance.currentUserId == null) return;
      await _uploadFCMTokenToAgora(newToken);
    });
  }
}

Future<void> _uploadFCMTokenToAgora(String fcmToken) async {
  try {
    await ChatClient.getInstance.pushManager.updateFCMPushToken(fcmToken);
    debugPrint('[Push] Android: FCM token uploaded to Agora');
  } catch (e) {
    debugPrint('[Push] Android: Error uploading FCM token to Agora: $e');
  }
}
