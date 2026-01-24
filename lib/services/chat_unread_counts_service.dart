import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logger.dart';

class ChatUnreadCountsService {
  final logger = getLogger(className: 'ChatUnreadCountsService');

  static final ChatUnreadCountsService _instance =
      ChatUnreadCountsService._internal();
  factory ChatUnreadCountsService() => _instance;
  ChatUnreadCountsService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  final ValueNotifier<Map<String, int>> unreadByClientId =
      ValueNotifier<Map<String, int>>({});
  final ValueNotifier<int> totalUnreadCount = ValueNotifier<int>(0);

  String? _coachId;
  final Map<String, String> _conversationToClientId = {};
  RealtimeChannel? _messagesChannel;
  RealtimeChannel? _conversationsChannel;

  Future<void> updateContext({required String? coachId}) async {
    if (coachId == null) {
      clear();
      return;
    }

    final isSameCoach =
        _coachId == coachId && _conversationToClientId.isNotEmpty;
    _coachId = coachId;

    if (!isSameCoach) {
      await _loadConversations();
      _subscribeConversations();
    }

    _subscribeMessages();
    await refreshUnreadCounts();
  }

  Future<void> _loadConversations() async {
    if (_coachId == null) return;
    try {
      final response = await _client
          .from('chat_conversations')
          .select('id, user_id')
          .eq('coach_id', _coachId!);
      final rows = (response as List<dynamic>)
          .map((row) => row as Map<String, dynamic>)
          .toList();
      _conversationToClientId
        ..clear()
        ..addEntries(
          rows.map((row) => MapEntry(
                row['id'] as String,
                row['user_id'] as String,
              )),
        );
    } catch (e) {
      logger.e('Error loading coach conversations: $e');
    }
  }

  void _subscribeConversations() {
    if (_coachId == null) return;
    _conversationsChannel?.let(_client.removeChannel);
    _conversationsChannel = _client
        .channel('chat_conversations_coach_$_coachId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_conversations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'coach_id',
            value: _coachId!,
          ),
          callback: (_) async {
            await _loadConversations();
            await refreshUnreadCounts();
          },
        )
        .subscribe();
  }

  void _subscribeMessages() {
    _messagesChannel?.let(_client.removeChannel);
    _messagesChannel = _client
        .channel('chat_messages_coach_$_coachId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          callback: (payload) {
            final conversationId = (payload.newRecord['conversation_id'] ??
                payload.oldRecord['conversation_id']) as String?;
            if (conversationId == null ||
                !_conversationToClientId.containsKey(conversationId)) {
              return;
            }
            unawaited(refreshUnreadCountForConversation(conversationId));
          },
        )
        .subscribe();
  }

  void refreshSubscription() {
    if (_coachId == null) return;
    _subscribeConversations();
    _subscribeMessages();
  }

  Future<void> refreshUnreadCounts() async {
    final coachId = _coachId;
    if (coachId == null || _conversationToClientId.isEmpty) {
      unreadByClientId.value = {};
      return;
    }

    try {
      final conversationIds = _conversationToClientId.keys.toList();
      final response = await _client
          .from('chat_messages')
          .select('conversation_id')
          .filter('conversation_id', 'in', '(${conversationIds.join(',')})')
          .neq('sender_id', coachId)
          .eq('is_read', false);

      final countsByConversation = <String, int>{};
      for (final row in (response as List<dynamic>)) {
        final conversationId = row['conversation_id'] as String?;
        if (conversationId == null) continue;
        countsByConversation[conversationId] =
            (countsByConversation[conversationId] ?? 0) + 1;
      }

      final countsByClient = <String, int>{};
      countsByConversation.forEach((conversationId, count) {
        final clientId = _conversationToClientId[conversationId];
        if (clientId == null) return;
        countsByClient[clientId] = count;
      });

      unreadByClientId.value = countsByClient;
      totalUnreadCount.value =
          countsByClient.values.fold<int>(0, (sum, count) => sum + count);
    } catch (e) {
      logger.e('Error refreshing coach unread counts: $e');
    }
  }

  Future<void> refreshUnreadCountForConversation(String conversationId) async {
    final coachId = _coachId;
    if (coachId == null) return;
    final clientId = _conversationToClientId[conversationId];
    if (clientId == null) return;

    try {
      final response = await _client
          .from('chat_messages')
          .select()
          .eq('conversation_id', conversationId)
          .neq('sender_id', coachId)
          .eq('is_read', false);
      final count = (response as List<dynamic>).length;

      final updated = Map<String, int>.from(unreadByClientId.value);
      if (count == 0) {
        updated.remove(clientId);
      } else {
        updated[clientId] = count;
      }
      unreadByClientId.value = updated;
      totalUnreadCount.value =
          updated.values.fold<int>(0, (sum, count) => sum + count);
    } catch (e) {
      logger.e('Error refreshing conversation unread count: $e');
    }
  }

  void clear() {
    _coachId = null;
    _conversationToClientId.clear();
    unreadByClientId.value = {};
    totalUnreadCount.value = 0;
    _messagesChannel?.let(_client.removeChannel);
    _conversationsChannel?.let(_client.removeChannel);
    _messagesChannel = null;
    _conversationsChannel = null;
  }
}

extension _ChannelDispose on RealtimeChannel? {
  void let(void Function(RealtimeChannel channel) fn) {
    final channel = this;
    if (channel != null) {
      fn(channel);
    }
  }
}
