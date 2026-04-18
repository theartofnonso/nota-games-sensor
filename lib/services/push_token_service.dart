import 'dart:async';
import 'dart:io' show Platform;

import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'user_device_token_service.dart';

bool _tokenRefreshListenerAdded = false;

// ---------------------------------------------------------------------------
// Backend push (all flavors) — single entry point
// ---------------------------------------------------------------------------

/// Syncs the device FCM token to Supabase `user_device_tokens` when the user
/// has granted notification permission, and attaches a token-refresh listener.
///
/// This is the **only** path the app should use for “our” push delivery (SendLoop,
/// nutrition nudges, etc.). It does **not** depend on Agora, chat, or flavor.
///
/// Call when the user is signed in: cold start, sign-in, app resume, and after
/// the user enables notifications in Settings.
Future<void> ensureFcmTokenSyncedToBackend() async {
  final granted = await isNotificationPermissionGranted();
  if (!granted) return;
  await syncFcmTokenToSupabase();
  _listenForTokenRefresh();
}

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
  if (Platform.isAndroid) {
    final plugin = FlutterLocalNotificationsPlugin();
    await plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }
  await FirebaseMessaging.instance.requestPermission();
}

// ---------------------------------------------------------------------------
// Agora Chat push (retail only) — after [ChatClient] login
// ---------------------------------------------------------------------------

/// Uploads the platform push token to **Agora** for chat notifications.
/// Call only after [ChatClient] login. Still updates Supabase via the shared
/// refresh listener / internal calls — backend FCM registration is owned by
/// [ensureFcmTokenSyncedToBackend].
///
/// **Android:** Get FCM token → upload to Agora → listen for token refresh.
/// **iOS:** Get APNs token via Firebase → upload to Agora → listen for refresh.
///
/// Returns true if the token was uploaded successfully, false otherwise.
Future<bool> setupPushToken() async {
  if (ChatClient.getInstance.currentUserId == null) {
    debugPrint('[Push] Not logged in to Agora; skip token setup.');
    return false;
  }

  if (Platform.isIOS) {
    return _setupiOSPushToken();
  } else if (Platform.isAndroid) {
    return _setupAndroidPushToken();
  }
  return false;
}

// ---------------------------------------------------------------------------
// iOS: APNs token (via Firebase) → Agora
// ---------------------------------------------------------------------------

Future<bool> _setupiOSPushToken() async {
  final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
  if (apnsToken == null) {
    debugPrint('[Push] iOS: APNs token is null');
    return false;
  }
  debugPrint('[Push] iOS: APNs token obtained');
  final ok = await _uploadAPNSTokenToAgora(apnsToken);
  unawaited(syncFcmTokenToSupabase());
  _listenForTokenRefresh();
  return ok;
}

Future<bool> _uploadAPNSTokenToAgora(String apnsToken) async {
  try {
    await ChatClient.getInstance.pushManager.updateAPNsDeviceToken(apnsToken);
    debugPrint('[Push] iOS: APNs token uploaded to Agora');
    return true;
  } catch (e) {
    debugPrint('[Push] iOS: Error uploading APNs token to Agora: $e');
    return false;
  }
}

// ---------------------------------------------------------------------------
// Android: FCM token → Agora
// ---------------------------------------------------------------------------

Future<bool> _setupAndroidPushToken() async {
  final fcmToken = await FirebaseMessaging.instance.getToken();
  if (fcmToken == null) {
    debugPrint('[Push] Android: FCM token is null');
    return false;
  }
  debugPrint('[Push] Android: FCM token obtained');
  final ok = await _uploadFCMTokenToAgora(fcmToken);
  unawaited(syncFcmTokenToSupabase());
  _listenForTokenRefresh();
  return ok;
}

Future<bool> _uploadFCMTokenToAgora(String fcmToken) async {
  try {
    await ChatClient.getInstance.pushManager.updateFCMPushToken(fcmToken);
    debugPrint('[Push] Android: FCM token uploaded to Agora');
    return true;
  } catch (e) {
    debugPrint('[Push] Android: Error uploading FCM token to Agora: $e');
    return false;
  }
}

// ---------------------------------------------------------------------------
// Shared: token refresh listener (works for both platforms)
// ---------------------------------------------------------------------------

void _listenForTokenRefresh() {
  if (_tokenRefreshListenerAdded) return;
  _tokenRefreshListenerAdded = true;

  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    debugPrint('[Push] Token refreshed');
    if (ChatClient.getInstance.currentUserId != null) {
      if (Platform.isAndroid) {
        await _uploadFCMTokenToAgora(newToken);
      } else if (Platform.isIOS) {
        // On iOS, onTokenRefresh gives the FCM token, not APNs.
        // Re-fetch APNs token and upload.
        final apnsToken = await FirebaseMessaging.instance.getAPNSToken();
        if (apnsToken != null) {
          await _uploadAPNSTokenToAgora(apnsToken);
        }
      }
    }
    unawaited(syncFcmTokenToSupabase());
  });
}
