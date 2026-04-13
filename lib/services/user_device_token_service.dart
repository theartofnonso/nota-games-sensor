import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

const String _deviceIdKey = 'user_device_token_device_id';

/// Syncs FCM device tokens to Supabase for backend push notifications (SendLoop/FCM).
/// Called from [ensureFcmTokenSyncedToBackend] and [setupPushToken] refresh paths.
///
/// Maps user_id → device tokens so the backend can deliver push notifications
/// across all of a user's devices.
Future<void> syncFcmTokenToSupabase() async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) {
    debugPrint('[DeviceToken] No authenticated user; skip sync');
    return;
  }

  final token = await FirebaseMessaging.instance.getToken();
  if (token == null || token.isEmpty) {
    debugPrint('[DeviceToken] FCM token is null or empty');
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  String deviceId = prefs.getString(_deviceIdKey) ?? '';
  if (deviceId.isEmpty) {
    deviceId = const Uuid().v4();
    await prefs.setString(_deviceIdKey, deviceId);
  }

  final platform = Platform.isAndroid ? 'android' : 'ios';

  try {
    await Supabase.instance.client.from('user_device_tokens').upsert(
      {
        'user_id': userId,
        'device_id': deviceId,
        'device_token': token,
        'platform': platform,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'user_id,device_id',
    );
    debugPrint('[DeviceToken] FCM token synced to Supabase');
  } catch (e) {
    debugPrint('[DeviceToken] Error syncing to Supabase: $e');
  }
}
