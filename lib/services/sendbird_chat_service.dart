import 'dart:async';
import 'package:sendbird_chat_sdk/sendbird_chat_sdk.dart' as sendbird;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../logger.dart';

/// Service for managing Sendbird chat connections and channels
/// Handles one-to-one messaging between users and the platform admin/coach
class SendbirdChatService {
  final logger = getLogger(className: "SendbirdChatService");
  
  static final SendbirdChatService _instance = SendbirdChatService._internal();
  factory SendbirdChatService() => _instance;
  SendbirdChatService._internal();

  sendbird.User? _currentUser;
  sendbird.GroupChannel? _currentGroupChannel;
  
  // Stream controllers for real-time updates
  final _messageController = StreamController<sendbird.BaseMessage>.broadcast();
  final _channelController = StreamController<sendbird.GroupChannel>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  // Getters for streams
  Stream<sendbird.BaseMessage> get messageStream => _messageController.stream;
  Stream<sendbird.GroupChannel> get channelStream => _channelController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Initialize Sendbird SDK with app ID
  /// Note: Replace with your actual Sendbird App ID
  Future<void> initialize({required String appId}) async {
    try {
      sendbird.SendbirdChat.init(appId: appId);
      logger.i('Sendbird SDK initialized');
    } catch (e) {
      logger.e('Error initializing Sendbird SDK: $e');
      rethrow;
    }
  }

  /// Connect to Sendbird with current user
  /// Creates a unique user ID based on Supabase user ID
  Future<sendbird.User> connect({String? userId, String? nickname}) async {
    try {
      // Get user ID from Supabase if not provided
      final currentSupabaseUser = Supabase.instance.client.auth.currentUser;
      final finalUserId = userId ?? currentSupabaseUser?.id;
      
      if (finalUserId == null) {
        throw Exception('No user ID available. User must be authenticated.');
      }

      // Connect to Sendbird
      _currentUser = await sendbird.SendbirdChat.connect(finalUserId);
      
      // Update user nickname if provided
      if (nickname != null || currentSupabaseUser?.email != null) {
        try {
          final updateParams = sendbird.UserUpdateParams()
            ..nickname = nickname ?? currentSupabaseUser!.email!.split('@')[0];
          await _currentUser!.updateUserInfo(updateParams);
        } catch (e) {
          // User update may not be available in all SDK versions
          logger.w('Could not update user info: $e');
        }
      }

      _connectionController.add(true);
      logger.i('Connected to Sendbird as user: ${_currentUser!.userId}');
      
      return _currentUser!;
    } catch (e) {
      logger.e('Error connecting to Sendbird: $e');
      _connectionController.add(false);
      rethrow;
    }
  }

  /// Disconnect from Sendbird
  Future<void> disconnect() async {
    try {
      await sendbird.SendbirdChat.disconnect();
      _currentUser = null;
      _currentGroupChannel = null;
      _connectionController.add(false);
      logger.i('Disconnected from Sendbird');
    } catch (e) {
      logger.e('Error disconnecting from Sendbird: $e');
    }
  }

  /// Get or create a one-to-one channel with the platform admin/coach
  /// Channel URL format: "user_{userId}_admin" ensures unique channel per user
  Future<sendbird.GroupChannel> getOrCreateUserChannel({
    required String adminUserId,
    String? channelName,
  }) async {
    try {
      if (_currentUser == null) {
        throw Exception('Not connected to Sendbird. Call connect() first.');
      }

      final userId = _currentUser!.userId;
      final channelUrl = 'user_${userId}_admin';

      // Try to get existing channel
      try {
        _currentGroupChannel = await sendbird.GroupChannel.getChannel(channelUrl);
        logger.i('Retrieved existing channel: $channelUrl');
        return _currentGroupChannel!;
      } catch (e) {
        // Channel doesn't exist, will be created by backend
        // For now, we'll create it here (backend should handle this in production)
        logger.i('Channel not found, will be created by backend: $channelUrl');
        
        // Note: In production, channel creation should be handled by backend
        // This is a fallback for development
        final params = sendbird.GroupChannelCreateParams()
          ..userIds = [userId, adminUserId]
          ..name = channelName ?? 'Support Chat'
          ..isDistinct = true
          ..customType = 'user_support';

        _currentGroupChannel = await sendbird.GroupChannel.createChannel(params);
        logger.i('Created new channel: ${_currentGroupChannel!.channelUrl}');
        
        return _currentGroupChannel!;
      }
    } catch (e) {
      logger.e('Error getting/creating user channel: $e');
      rethrow;
    }
  }

  /// Send a text message to the current channel
  Future<sendbird.UserMessage> sendMessage(String message) async {
    try {
      if (_currentGroupChannel == null) {
        throw Exception('No active channel. Call getOrCreateUserChannel() first.');
      }

      final params = sendbird.UserMessageCreateParams(message: message);
      final sentMessage = await _currentGroupChannel!.sendUserMessage(params);
      
      _messageController.add(sentMessage);
      logger.i('Message sent: ${sentMessage.messageId}');
      
      return sentMessage;
    } catch (e) {
      logger.e('Error sending message: $e');
      rethrow;
    }
  }

  /// Load previous messages from the channel
  Future<List<sendbird.RootMessage>> loadPreviousMessages({
    int limit = 50,
    sendbird.MessageListParams? params,
  }) async {
    try {
      if (_currentGroupChannel == null) {
        throw Exception('No active channel. Call getOrCreateUserChannel() first.');
      }

      final messageListParams = params ?? sendbird.MessageListParams()
        ..nextResultSize = limit
        ..reverse = true;

      final messages = await _currentGroupChannel!.getMessagesByTimestamp(
        DateTime.now().millisecondsSinceEpoch,
        messageListParams,
      );

      logger.i('Loaded ${messages.length} previous messages');
      return messages;
    } catch (e) {
      logger.e('Error loading previous messages: $e');
      rethrow;
    }
  }

  /// Mark messages as read
  Future<void> markAsRead() async {
    try {
      if (_currentGroupChannel != null) {
        await _currentGroupChannel!.markAsRead();
        logger.i('Messages marked as read');
      }
    } catch (e) {
      logger.e('Error marking messages as read: $e');
    }
  }

  /// Set up channel event handlers for real-time updates
  void setupChannelHandlers() {
    final handler = _ChatChannelHandler(
      onMessageReceivedCallback: (sendbird.BaseChannel channel, sendbird.BaseMessage message) {
        if (channel is sendbird.GroupChannel && channel == _currentGroupChannel) {
          _messageController.add(message);
          markAsRead(); // Auto-mark as read
        }
      },
      onMessageUpdatedCallback: (sendbird.BaseChannel channel, sendbird.BaseMessage message) {
        if (channel is sendbird.GroupChannel && channel == _currentGroupChannel) {
          _messageController.add(message);
        }
      },
      onMessageDeletedCallback: (sendbird.BaseChannel channel, int messageId) {
        // Handle message deletion if needed
        logger.i('Message deleted: $messageId');
      },
      onChannelChangedCallback: (sendbird.BaseChannel channel) {
        if (channel is sendbird.GroupChannel && channel == _currentGroupChannel) {
          _channelController.add(channel);
        }
      },
    );
    
    sendbird.SendbirdChat.addChannelHandler('chat_handler', handler);
  }

  /// Get unread message count for the current channel
  int getUnreadCount() {
    return _currentGroupChannel?.unreadMessageCount ?? 0;
  }

  /// Get current channel
  sendbird.GroupChannel? get currentChannel => _currentGroupChannel;

  /// Get current user
  sendbird.User? get currentUser => _currentUser;

  /// Check if connected
  bool get isConnected => _currentUser != null;

  /// Dispose resources
  void dispose() {
    sendbird.SendbirdChat.removeChannelHandler('chat_handler');
    _messageController.close();
    _channelController.close();
    _connectionController.close();
    disconnect();
  }
}

/// Channel event handler for Sendbird
class _ChatChannelHandler extends sendbird.GroupChannelHandler {
  final void Function(sendbird.BaseChannel channel, sendbird.BaseMessage message) onMessageReceivedCallback;
  final void Function(sendbird.BaseChannel channel, sendbird.BaseMessage message) onMessageUpdatedCallback;
  final void Function(sendbird.BaseChannel channel, int messageId) onMessageDeletedCallback;
  final void Function(sendbird.BaseChannel channel) onChannelChangedCallback;

  _ChatChannelHandler({
    required this.onMessageReceivedCallback,
    required this.onMessageUpdatedCallback,
    required this.onMessageDeletedCallback,
    required this.onChannelChangedCallback,
  });

  @override
  void onMessageReceived(sendbird.BaseChannel channel, sendbird.BaseMessage message) {
    onMessageReceivedCallback(channel, message);
  }

  @override
  void onMessageUpdated(sendbird.BaseChannel channel, sendbird.BaseMessage message) {
    onMessageUpdatedCallback(channel, message);
  }

  @override
  void onMessageDeleted(sendbird.BaseChannel channel, int messageId) {
    onMessageDeletedCallback(channel, messageId);
  }

  @override
  void onChannelChanged(sendbird.BaseChannel channel) {
    onChannelChangedCallback(channel);
  }
}
