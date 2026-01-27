import 'dart:async';

import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:flutter/foundation.dart';

import '../utils/agora_chat_utils.dart';

class ChatUnreadService {
  static final ChatUnreadService _instance = ChatUnreadService._internal();
  factory ChatUnreadService() => _instance;
  ChatUnreadService._internal();

  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  ChatConversation? _conversation;
  String? _targetAgoraUserId;
  String? _handlerId;

  Future<void> updateContext({
    required String? userId,
    required String coachId,
    String? userIdOverride,
  }) async {
    final resolvedUserId = userIdOverride ?? userId;
    if (resolvedUserId == null) {
      clear();
      return;
    }

    // Chat SDK is already initialized in main.dart
    _targetAgoraUserId = toAgoraUsername(coachId);
    _handlerId ??= 'chat_unread_${resolvedUserId}_$coachId';

    await _loadConversation();
    refreshSubscription();
    await refreshUnreadCount();
  }

  Future<void> _loadConversation() async {
    final targetId = _targetAgoraUserId;
    if (targetId == null) {
      _conversation = null;
      return;
    }
    _conversation = await ChatClient.getInstance.chatManager.getConversation(
      targetId,
      type: ChatConversationType.Chat,
      createIfNeed: true,
    );
  }

  void refreshSubscription() {
    final handlerId = _handlerId;
    if (handlerId == null) return;
    ChatClient.getInstance.chatManager.removeEventHandler(handlerId);
    ChatClient.getInstance.chatManager.addEventHandler(
      handlerId,
      ChatEventHandler(
        onMessagesReceived: (messages) {
          final targetId = _targetAgoraUserId;
          if (targetId == null) return;
          final hasMatch = messages.any((m) => m.from == targetId);
          if (hasMatch) {
            unawaited(refreshUnreadCount());
          }
        },
      ),
    );
  }

  Future<void> refreshUnreadCount() async {
    final conversation = _conversation;
    if (conversation == null) return;
    try {
      final count = await conversation.unreadCount();
      unreadCount.value = count;
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    final conversation = _conversation;
    if (conversation == null) return;
    try {
      await conversation.markAllMessagesAsRead();
      unreadCount.value = 0;
    } catch (_) {}
  }

  void clear() {
    unreadCount.value = 0;
    _conversation = null;
    _targetAgoraUserId = null;
    final handlerId = _handlerId;
    if (handlerId != null) {
      ChatClient.getInstance.chatManager.removeEventHandler(handlerId);
    }
    _handlerId = null;
  }
}
