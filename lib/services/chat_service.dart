import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../dtos/appsync/chat_message_dto.dart';
import '../logger.dart';

/// Service for managing chat conversations and messages
/// Handles one-to-one messaging between users and coaches using Supabase
enum ChatMessageEventType { insert, update, delete }

class ChatMessageEvent {
  final ChatMessageEventType type;
  final ChatMessageDto? message;
  final String? messageId;

  const ChatMessageEvent({
    required this.type,
    this.message,
    this.messageId,
  });
}

class ChatService {
  final logger = getLogger(className: "ChatService");

  static final ChatService _instance = ChatService._internal();
  factory ChatService() => _instance;
  ChatService._internal();

  final SupabaseClient _client = Supabase.instance.client;

  String? _currentConversationId;

  // Stream controller for real-time message updates
  final _messageController = StreamController<ChatMessageEvent>.broadcast();
  RealtimeChannel? _messageSubscription;

  /// Get message stream for real-time updates
  Stream<ChatMessageEvent> get messageStream => _messageController.stream;

  /// Get or create a conversation between current user and coach
  /// Returns the conversation ID
  Future<String> getOrCreateConversation({
    required String coachId,
    String? userIdOverride,
  }) async {
    try {
      final userId = userIdOverride ?? _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No user ID available. User must be authenticated.');
      }

      // Check if conversation already exists
      final existingResponse = await _client
          .from('chat_conversations')
          .select()
          .eq('user_id', userId)
          .eq('coach_id', coachId)
          .maybeSingle();

      if (existingResponse != null) {
        _currentConversationId = existingResponse['id'] as String;
        logger.i('Found existing conversation: $_currentConversationId');
        return _currentConversationId!;
      }

      // Create new conversation
      final createResponse = await _client
          .from('chat_conversations')
          .insert({
            'user_id': userId,
            'coach_id': coachId,
            'created_at': DateTime.now().toIso8601String(),
            'last_message_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      _currentConversationId = createResponse['id'] as String;
      logger.i('Created new conversation: $_currentConversationId');

      return _currentConversationId!;
    } catch (e) {
      logger.e('Error getting/creating conversation: $e');
      rethrow;
    }
  }

  /// Send a text message to the current conversation
  Future<ChatMessageDto> sendMessage(String text) async {
    try {
      if (_currentConversationId == null) {
        throw Exception(
            'No active conversation. Call getOrCreateConversation() first.');
      }

      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No user ID available. User must be authenticated.');
      }

      // Insert message
      final response = await _client
          .from('chat_messages')
          .insert({
            'conversation_id': _currentConversationId,
            'sender_id': userId,
            'content': text,
          })
          .select()
          .single();

      // Update conversation's last_message_at
      await _client
          .from('chat_conversations')
          .update({'last_message_at': DateTime.now().toIso8601String()}).eq(
              'id', _currentConversationId!);

      final message = ChatMessageDto.fromJson(json: response);

      // Emit to stream immediately
      _messageController.add(
        ChatMessageEvent(type: ChatMessageEventType.insert, message: message),
      );

      logger.i('Message sent: ${message.id}');

      return message;
    } catch (e) {
      logger.e('Error sending message: $e');
      rethrow;
    }
  }

  /// Load previous messages from the conversation
  /// Returns messages ordered by creation time (oldest first)
  Future<List<ChatMessageDto>> loadPreviousMessages({int limit = 50}) async {
    try {
      if (_currentConversationId == null) {
        throw Exception(
            'No active conversation. Call getOrCreateConversation() first.');
      }

      var query = _client
          .from('chat_messages')
          .select()
          .eq('conversation_id', _currentConversationId!)
          .order('created_at', ascending: true)
          .limit(limit);

      final response = await query;

      final messages = (response as List<dynamic>)
          .map((item) =>
              ChatMessageDto.fromJson(json: Map<String, dynamic>.from(item)))
          .toList();

      logger.i('Loaded ${messages.length} previous messages');
      return messages;
    } catch (e) {
      logger.e('Error loading previous messages: $e');
      rethrow;
    }
  }

  /// Set up real-time subscription for new messages
  /// Uses Supabase Realtime to listen for new messages
  void setupMessageSubscription() {
    try {
      if (_currentConversationId == null) {
        logger.w('Cannot setup subscription: no active conversation');
        return;
      }

      // Remove existing subscription if any
      if (_messageSubscription != null) {
        _client.removeChannel(_messageSubscription!);
      }

      // Subscribe to new messages for this conversation
      _messageSubscription = _client
          .channel('chat_messages:$_currentConversationId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'chat_messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: _currentConversationId!,
            ),
            callback: (payload) {
              try {
                final eventType = payload.eventType;
                if (eventType == PostgresChangeEvent.insert) {
                  final message =
                      ChatMessageDto.fromJson(json: payload.newRecord);
                  _messageController.add(
                    ChatMessageEvent(
                      type: ChatMessageEventType.insert,
                      message: message,
                    ),
                  );
                  return;
                }
                if (eventType == PostgresChangeEvent.update) {
                  final message =
                      ChatMessageDto.fromJson(json: payload.newRecord);
                  _messageController.add(
                    ChatMessageEvent(
                      type: ChatMessageEventType.update,
                      message: message,
                    ),
                  );
                  return;
                }
                if (eventType == PostgresChangeEvent.delete) {
                  final id = payload.oldRecord['id'] as String;
                  _messageController.add(
                    ChatMessageEvent(
                      type: ChatMessageEventType.delete,
                      messageId: id,
                    ),
                  );
                }
              } catch (e) {
                logger.e('Error processing realtime message: $e');
              }
            },
          )
          .subscribe();

      logger.i(
          'Message subscription set up for conversation: $_currentConversationId');
    } catch (e) {
      logger.e('Error setting up message subscription: $e');
      rethrow;
    }
  }

  /// Get current conversation ID
  String? get currentConversationId => _currentConversationId;

  /// Get current user ID
  String? get currentUserId => _client.auth.currentUser?.id;

  /// Mark all messages in the current conversation as read
  Future<void> markConversationAsRead() async {
    if (_currentConversationId == null) return;
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    await _client
        .from('chat_messages')
        .update({'is_read': true})
        .eq('conversation_id', _currentConversationId!)
        .neq('sender_id', userId)
        .eq('is_read', false);
  }

  /// Cleanup resources
  void dispose() {
    if (_messageSubscription != null) {
      _client.removeChannel(_messageSubscription!);
      _messageSubscription = null;
    }

    _currentConversationId = null;
  }
}
