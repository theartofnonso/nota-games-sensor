import 'dart:async';
import 'package:flutter/material.dart';
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
  bool _isInitialized = false;
  String? _appId;
  
  // Stream controllers for real-time updates
  final _messageController = StreamController<sendbird.BaseMessage>.broadcast();
  final _channelController = StreamController<sendbird.GroupChannel>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  // Handler IDs for cleanup
  static const String _channelHandlerId = 'chat_channel_handler';
  static const String _connectionHandlerId = 'chat_connection_handler';

  // Getters for streams
  Stream<sendbird.BaseMessage> get messageStream => _messageController.stream;
  Stream<sendbird.GroupChannel> get channelStream => _channelController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;

  /// Initialize Sendbird SDK with app ID
  /// Should be called once at app startup. Safe to call multiple times.
  Future<void> initialize({required String appId}) async {
    try {
      // Only initialize if not already initialized or if app ID changed
      if (_isInitialized && _appId == appId) {
        logger.i('Sendbird SDK already initialized');
        return;
      }

      sendbird.SendbirdChat.init(appId: appId);
      _appId = appId;
      _isInitialized = true;
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
      if (!_isInitialized) {
        throw Exception('Sendbird SDK not initialized. Call initialize() first.');
      }

      // Get user ID from Supabase if not provided
      final currentSupabaseUser = Supabase.instance.client.auth.currentUser;
      final finalUserId = userId ?? currentSupabaseUser?.id;
      
      if (finalUserId == null) {
        throw Exception('No user ID available. User must be authenticated.');
      }

      // Disconnect existing connection if user ID changed
      if (_currentUser != null && _currentUser!.userId != finalUserId) {
        await disconnect();
      }

      // Connect to Sendbird
      _currentUser = await sendbird.SendbirdChat.connect(finalUserId);
      
      // Update user nickname if provided
      // Note: User profile updates should be done via Sendbird Dashboard or Platform API
      // SDK-level updates may not be available in all versions
      if (nickname != null || currentSupabaseUser?.email != null) {
        try {
          // Try to update user info if the method exists
          // This is optional and may not be available in all SDK versions
          logger.d('User nickname would be: ${nickname ?? currentSupabaseUser!.email!.split('@')[0]}');
          // User updates should ideally be handled server-side
        } catch (e) {
          logger.w('Could not update user info: $e');
        }
      }

      // Set up connection handler for reconnection
      _setupConnectionHandler();

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
  /// Uses isDistinct=true to ensure only one channel exists between the same users
  Future<sendbird.GroupChannel> getOrCreateUserChannel({
    required String adminUserId,
    String? channelName,
  }) async {
    try {
      if (_currentUser == null) {
        throw Exception('Not connected to Sendbird. Call connect() first.');
      }

      final userId = _currentUser!.userId;

      // Use isDistinct=true to automatically reuse existing channel if it exists
      // This is the recommended approach per Sendbird documentation
      final params = sendbird.GroupChannelCreateParams()
        ..userIds = [userId, adminUserId]
        ..name = channelName ?? 'Support Chat'
        ..isDistinct = true // This ensures only one channel between these users
        ..customType = 'user_support';

      // createChannel will return existing channel if isDistinct=true and channel exists
      _currentGroupChannel = await sendbird.GroupChannel.createChannel(params);
      logger.i('Channel ready: ${_currentGroupChannel!.channelUrl}');
      
      return _currentGroupChannel!;
    } catch (e) {
      logger.e('Error getting/creating user channel: $e');
      // Check for specific Sendbird error codes
      if (e is sendbird.SendbirdException) {
        if (e.code == 400201) {
          // User not found - admin user might not exist
          throw Exception('Admin user not found. Please ensure the admin user exists in Sendbird.');
        }
      }
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
  /// Uses proper pagination with timestamp-based loading
  Future<List<sendbird.RootMessage>> loadPreviousMessages({
    int limit = 50,
    int? timestamp,
    sendbird.MessageListParams? params,
  }) async {
    try {
      if (_currentGroupChannel == null) {
        throw Exception('No active channel. Call getOrCreateUserChannel() first.');
      }

      final messageListParams = params ?? sendbird.MessageListParams()
        ..nextResultSize = limit
        ..reverse = false; // false means older messages (previous)

      final targetTimestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;
      final messages = await _currentGroupChannel!.getMessagesByTimestamp(
        targetTimestamp,
        messageListParams,
      );

      logger.i('Loaded ${messages.length} previous messages');
      return messages;
    } catch (e) {
      logger.e('Error loading previous messages: $e');
      if (e is sendbird.SendbirdException) {
        if (e.code == 800101) {
          throw Exception('Connection required. Please ensure you are connected to Sendbird.');
        }
      }
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
  /// Removes existing handler before adding new one to prevent duplicates
  void setupChannelHandlers() {
    // Remove existing handler if it exists
    try {
      sendbird.SendbirdChat.removeChannelHandler(_channelHandlerId);
    } catch (e) {
      // Handler might not exist, which is fine
      logger.d('No existing channel handler to remove');
    }

    final handler = _ChatChannelHandler(
      onMessageReceivedCallback: (sendbird.BaseChannel channel, sendbird.BaseMessage message) {
        if (channel is sendbird.GroupChannel && 
            channel.channelUrl == _currentGroupChannel?.channelUrl) {
          _messageController.add(message);
          markAsRead(); // Auto-mark as read
        }
      },
      onMessageUpdatedCallback: (sendbird.BaseChannel channel, sendbird.BaseMessage message) {
        if (channel is sendbird.GroupChannel && 
            channel.channelUrl == _currentGroupChannel?.channelUrl) {
          _messageController.add(message);
        }
      },
      onMessageDeletedCallback: (sendbird.BaseChannel channel, int messageId) {
        if (channel is sendbird.GroupChannel && 
            channel.channelUrl == _currentGroupChannel?.channelUrl) {
          logger.i('Message deleted: $messageId');
          // Could emit a deletion event here if needed
        }
      },
      onChannelChangedCallback: (sendbird.BaseChannel channel) {
        if (channel is sendbird.GroupChannel && 
            channel.channelUrl == _currentGroupChannel?.channelUrl) {
          _currentGroupChannel = channel;
          _channelController.add(_currentGroupChannel!);
        }
      },
    );
    
    sendbird.SendbirdChat.addChannelHandler(_channelHandlerId, handler);
    logger.i('Channel handlers set up');
  }

  /// Set up connection handler for reconnection handling
  void _setupConnectionHandler() {
    // Remove existing handler if it exists
    try {
      sendbird.SendbirdChat.removeConnectionHandler(_connectionHandlerId);
    } catch (e) {
      // Handler might not exist, which is fine
      logger.d('No existing connection handler to remove');
    }

    final connectionHandler = _ChatConnectionHandler(
      onReconnectSucceeded: () {
        logger.i('Reconnected to Sendbird');
        _connectionController.add(true);
      },
      onReconnectFailed: () {
        logger.w('Reconnection to Sendbird failed');
        _connectionController.add(false);
      },
      onConnectionChanged: (bool isConnected) {
        logger.i('Connection changed: $isConnected');
        _connectionController.add(isConnected);
      },
    );

    sendbird.SendbirdChat.addConnectionHandler(_connectionHandlerId, connectionHandler);
    logger.i('Connection handler set up');
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
    try {
      sendbird.SendbirdChat.removeChannelHandler(_channelHandlerId);
      sendbird.SendbirdChat.removeConnectionHandler(_connectionHandlerId);
    } catch (e) {
      logger.w('Error removing handlers: $e');
    }
    _messageController.close();
    _channelController.close();
    _connectionController.close();
    disconnect();
  }
}

/// Channel event handler for Sendbird
/// Uses RootChannelHandler which handles all channel types
class _ChatChannelHandler extends sendbird.RootChannelHandler {
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

  void onMessageReceived(sendbird.BaseChannel channel, sendbird.BaseMessage message) {
    onMessageReceivedCallback(channel, message);
  }

  void onMessageUpdated(sendbird.BaseChannel channel, sendbird.BaseMessage message) {
    onMessageUpdatedCallback(channel, message);
  }

  void onMessageDeleted(sendbird.BaseChannel channel, int messageId) {
    onMessageDeletedCallback(channel, messageId);
  }

  void onChannelChanged(sendbird.BaseChannel channel) {
    onChannelChangedCallback(channel);
  }
}

/// Connection event handler for Sendbird
/// Handles reconnection events
class _ChatConnectionHandler extends sendbird.ConnectionHandler {
  final VoidCallback _onReconnectSucceeded;
  final VoidCallback _onReconnectFailed;
  final void Function(bool isConnected) _onConnectionChanged;

  _ChatConnectionHandler({
    required VoidCallback onReconnectSucceeded,
    required VoidCallback onReconnectFailed,
    required void Function(bool isConnected) onConnectionChanged,
  })  : _onReconnectSucceeded = onReconnectSucceeded,
        _onReconnectFailed = onReconnectFailed,
        _onConnectionChanged = onConnectionChanged;

  @override
  void onConnected(String sessionKey) {
    _onConnectionChanged(true);
  }

  @override
  void onDisconnected(String sessionKey) {
    _onConnectionChanged(false);
  }

  @override
  void onReconnectStarted() {
    // Reconnection started - connection state is already false
  }

  @override
  void onReconnectSucceeded() {
    _onReconnectSucceeded();
  }

  @override
  void onReconnectFailed() {
    _onReconnectFailed();
  }
}
