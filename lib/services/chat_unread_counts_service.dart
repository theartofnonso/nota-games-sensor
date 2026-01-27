import 'dart:async';

import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:flutter/foundation.dart';

import '../utils/agora_chat_utils.dart';

class ChatUnreadCountsService {
  static final ChatUnreadCountsService _instance =
      ChatUnreadCountsService._internal();
  factory ChatUnreadCountsService() => _instance;
  ChatUnreadCountsService._internal();

  final ValueNotifier<Map<String, int>> unreadByClientId =
      ValueNotifier<Map<String, int>>({});
  final ValueNotifier<int> totalUnreadCount = ValueNotifier<int>(0);

  final Map<String, String> _clientIdToAgora = {};
  String? _handlerId;

  Future<void> updateClients(List<String> clientIds) async {
    // Chat SDK is already initialized in main.dart
    _clientIdToAgora
      ..clear()
      ..addEntries(
        clientIds.map((id) => MapEntry(id, toAgoraUsername(id))),
      );
    _handlerId ??= 'chat_unread_counts_${clientIds.hashCode}';
    refreshSubscription();
    await refreshUnreadCounts();
    await refreshTotalUnreadCount();
  }

  void refreshSubscription() {
    final handlerId = _handlerId;
    if (handlerId == null) return;
    ChatClient.getInstance.chatManager.removeEventHandler(handlerId);
    ChatClient.getInstance.chatManager.addEventHandler(
      handlerId,
      ChatEventHandler(
        onMessagesReceived: (messages) {
          final targetIds = _clientIdToAgora.values.toSet();
          for (final message in messages) {
            final from = message.from;
            if (targetIds.contains(from)) {
              final clientId = _clientIdToAgora.entries
                  .firstWhere((entry) => entry.value == from)
                  .key;
              unawaited(refreshUnreadCountForClient(clientId));
            }
          }
          unawaited(refreshTotalUnreadCount());
        },
      ),
    );
  }

  Future<void> refreshUnreadCounts() async {
    if (_clientIdToAgora.isEmpty) {
      unreadByClientId.value = {};
      totalUnreadCount.value = 0;
      return;
    }

    final updated = <String, int>{};
    for (final entry in _clientIdToAgora.entries) {
      final count = await _fetchUnreadCount(entry.value);
      if (count > 0) {
        updated[entry.key] = count;
      }
    }
    unreadByClientId.value = updated;
    totalUnreadCount.value =
        updated.values.fold<int>(0, (sum, count) => sum + count);
  }

  Future<void> refreshUnreadCountForClient(String clientId) async {
    final agoraId = _clientIdToAgora[clientId];
    if (agoraId == null) return;
    final count = await _fetchUnreadCount(agoraId);

    final updated = Map<String, int>.from(unreadByClientId.value);
    if (count == 0) {
      updated.remove(clientId);
    } else {
      updated[clientId] = count;
    }
    unreadByClientId.value = updated;
    totalUnreadCount.value =
        updated.values.fold<int>(0, (sum, count) => sum + count);
  }

  Future<void> refreshTotalUnreadCount() async {
    final total =
        unreadByClientId.value.values.fold<int>(0, (sum, count) => sum + count);
    totalUnreadCount.value = total;
  }

  Future<int> _fetchUnreadCount(String agoraUserId) async {
    try {
      final conversation =
          await ChatClient.getInstance.chatManager.getConversation(
        agoraUserId,
        type: ChatConversationType.Chat,
        createIfNeed: true,
      );
      return await conversation!.unreadCount();
    } catch (_) {
      return 0;
    }
  }

  void clear() {
    unreadByClientId.value = {};
    totalUnreadCount.value = 0;
    _clientIdToAgora.clear();
    final handlerId = _handlerId;
    if (handlerId != null) {
      ChatClient.getInstance.chatManager.removeEventHandler(handlerId);
    }
    _handlerId = null;
  }
}
