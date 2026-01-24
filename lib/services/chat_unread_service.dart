import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../logger.dart';

class ChatUnreadService {
  final logger = getLogger(className: 'ChatUnreadService');

  static final ChatUnreadService _instance = ChatUnreadService._internal();
  factory ChatUnreadService() => _instance;
  ChatUnreadService._internal();

  final SupabaseClient _client = Supabase.instance.client;
  final ValueNotifier<int> unreadCount = ValueNotifier<int>(0);

  RealtimeChannel? _channel;
  String? _conversationId;
  String? _currentUserId;
  String? _currentCoachId;

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

    final sameContext = _currentUserId == resolvedUserId &&
        _currentCoachId == coachId &&
        _conversationId != null;
    _currentUserId = resolvedUserId;
    _currentCoachId = coachId;

    if (sameContext) {
      await refreshUnreadCount();
      refreshSubscription();
      return;
    }

    await _loadConversation();
    if (_conversationId == null) {
      unreadCount.value = 0;
      _unsubscribe();
      return;
    }

    refreshSubscription();
    await refreshUnreadCount();
  }

  Future<void> _loadConversation() async {
    if (_currentUserId == null || _currentCoachId == null) {
      _conversationId = null;
      return;
    }
    try {
      final conversation = await _client
          .from('chat_conversations')
          .select('id')
          .eq('user_id', _currentUserId!)
          .eq('coach_id', _currentCoachId!)
          .maybeSingle();
      _conversationId = conversation?['id'] as String?;
    } catch (e) {
      logger.e('Error loading conversation: $e');
      _conversationId = null;
    }
  }

  void refreshSubscription() {
    if (_conversationId == null) return;
    _unsubscribe();
    _channel = _client
        .channel('chat_messages_unread_$_conversationId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'chat_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'conversation_id',
            value: _conversationId!,
          ),
          callback: (_) {
            unawaited(refreshUnreadCount());
          },
        )
        .subscribe();
  }

  Future<void> refreshUnreadCount() async {
    final userId = _currentUserId;
    final conversationId = _conversationId;
    if (userId == null || conversationId == null) return;
    try {
      final response = await _client
          .from('chat_messages')
          .select()
          .eq('conversation_id', conversationId)
          .neq('sender_id', userId)
          .eq('is_read', false);
      unreadCount.value = (response as List).length;
    } catch (e) {
      logger.e('Error refreshing unread count: $e');
    }
  }

  void clear() {
    _currentUserId = null;
    _currentCoachId = null;
    _conversationId = null;
    unreadCount.value = 0;
    _unsubscribe();
  }

  void _unsubscribe() {
    if (_channel != null) {
      _client.removeChannel(_channel!);
      _channel = null;
    }
  }
}
