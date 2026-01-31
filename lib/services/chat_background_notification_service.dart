import 'dart:convert';

import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shows local notifications when chat messages arrive while the app is in
/// background. When the app is killed, Agora sends push via APNs. When the app
/// is backgrounded, Agora may deliver via the WebSocket (user still "online"),
/// so we show a local notification.
class ChatBackgroundNotificationService {
  ChatBackgroundNotificationService._();

  static const String _handlerId = 'chat_background_notification';
  static const int _chatNotificationIdBase = 6000;

  static bool _appInBackground = false;
  static bool _handlerRegistered = false;

  /// Call when app lifecycle changes. Use [AppLifecycleState.paused],
  /// [AppLifecycleState.inactive], or [AppLifecycleState.detached] for
  /// background.
  static void setAppInBackground(bool inBackground) {
    _appInBackground = inBackground;
  }

  static NotificationDetails? _notificationDetails;

  /// Provide notification details (call from main after plugin init).
  /// Uses chat channel for Android.
  static void setNotificationDetails(NotificationDetails details) {
    _notificationDetails = details;
  }

  /// Register Agora message handler to show local notifications when app is
  /// in background. Call after Agora login.
  static void registerHandler() {
    if (_handlerRegistered) return;
    final details = _notificationDetails;
    if (details == null) {
      debugPrint('[ChatBackgroundNotification] No details; skip handler');
      return;
    }
    _handlerRegistered = true;

    final plugin = FlutterLocalNotificationsPlugin();

    ChatClient.getInstance.chatManager.addEventHandler(
      _handlerId,
      ChatEventHandler(
        onMessagesReceived: (messages) {
          if (!_appInBackground) return;
          for (final message in messages) {
            _showNotificationForMessage(plugin, details, message);
          }
        },
      ),
    );
    debugPrint('[ChatBackgroundNotification] Handler registered');
  }

  static void _showNotificationForMessage(
    FlutterLocalNotificationsPlugin plugin,
    NotificationDetails details,
    ChatMessage message,
  ) {
    final body = message.body;
    String content = '';
    if (body is ChatTextMessageBody) {
      content = body.content;
    } else if (body is ChatFileMessageBody) {
      content = body.displayName ?? 'Attachment';
    } else if (body is ChatImageMessageBody) {
      content = 'Photo';
    } else if (body is ChatVideoMessageBody) {
      content = 'Video';
    } else {
      content = 'New message';
    }

    final from = message.from ?? 'Someone';
    final senderDisplay = _shortAgoraId(from);
    final title = 'New message from $senderDisplay';
    final payload = jsonEncode({'type': 'chat'});

    final id = _chatNotificationIdBase + (DateTime.now().millisecondsSinceEpoch % 1000);

    plugin.show(id, title, content, details, payload: payload);
  }

  static String _shortAgoraId(String agoraId) {
    final withoutPrefix = agoraId.replaceFirst(RegExp(r'^[a-z]+_'), '');
    if (withoutPrefix.length <= 12) return withoutPrefix;
    return '${withoutPrefix.substring(0, 8)}…';
  }

  /// Unregister the handler. Call on logout if needed.
  static void unregisterHandler() {
    if (!_handlerRegistered) return;
    ChatClient.getInstance.chatManager.removeEventHandler(_handlerId);
    _handlerRegistered = false;
    debugPrint('[ChatBackgroundNotification] Handler unregistered');
  }
}
