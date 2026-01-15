import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sendbird_chat_sdk/sendbird_chat_sdk.dart' as sendbird;
import '../../services/sendbird_chat_service.dart';
import '../../config/sendbird_config.dart';
import '../../utils/theme/color_extensions.dart';
import '../../widgets/backgrounds/trkr_loading_screen.dart';

class ChatScreen extends StatefulWidget {
  static const routeName = '/chat_screen';

  /// Admin/Coach user ID for the one-to-one chat
  final String adminUserId;

  /// Optional scroll controller for bottom sheet integration
  final ScrollController? scrollController;

  const ChatScreen({
    super.key,
    required this.adminUserId,
    this.scrollController,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final SendbirdChatService _chatService = SendbirdChatService();
  final TextEditingController _messageController = TextEditingController();
  late final ScrollController _scrollController;
  final List<sendbird.RootMessage> _messages = [];

  bool _isLoading = true;
  bool _isConnected = false;
  bool _isSending = false;
  StreamSubscription<sendbird.BaseMessage>? _messageSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      setState(() => _isLoading = true);

      // Initialize Sendbird
      await _chatService.initialize(appId: SendbirdConfig.appId);

      // Connect to Sendbird
      await _chatService.connect();
      setState(() => _isConnected = true);

      // Set up channel handlers
      _chatService.setupChannelHandlers();

      // Get or create user channel
      await _chatService.getOrCreateUserChannel(
        adminUserId: widget.adminUserId,
        channelName: 'Support Chat',
      );

      // Load previous messages
      final previousMessages =
          await _chatService.loadPreviousMessages(limit: 50);
      setState(() {
        _messages.addAll(previousMessages.reversed);
      });

      // Set up message stream listener
      _messageSubscription = _chatService.messageStream.listen((message) {
        if (!mounted) return;

        setState(() {
          // Check for duplicates using a combination of properties
          // For UserMessage, use messageId if available, otherwise use createdAt + sender
          final isDuplicate = _messages.any((m) {
            if (m is sendbird.UserMessage && message is sendbird.UserMessage) {
              // Use messageId for sent messages (more reliable)
              if (m.messageId > 0 && message.messageId > 0) {
                return m.messageId == message.messageId;
              }
              // Fallback: compare by createdAt and sender for pending messages
              return m.createdAt == message.createdAt &&
                  m.sender?.userId == message.sender?.userId;
            }
            // For other message types, compare by createdAt
            return m.createdAt == message.createdAt;
          });

          if (!isDuplicate) {
            _messages.add(message as sendbird.RootMessage);
            _scrollToBottom();
          }
        });
      });

      // Set up connection stream listener
      _connectionSubscription =
          _chatService.connectionStream.listen((connected) {
        setState(() => _isConnected = connected);
      });

      // Mark messages as read
      await _chatService.markAsRead();

      setState(() => _isLoading = false);
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error initializing chat: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to initialize chat: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await _chatService.sendMessage(messageText);
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error sending message: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      // Restore message text on error
      _messageController.text = messageText;
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  String _formatTimestamp(int timestamp) {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return DateFormat('HH:mm').format(date);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${DateFormat('HH:mm').format(date)}';
    } else {
      return DateFormat('MMM d, HH:mm').format(date);
    }
  }

  bool _isCurrentUserMessage(sendbird.RootMessage message) {
    if (message is sendbird.UserMessage) {
      return message.sender?.userId == _chatService.currentUser?.userId;
    }
    return false;
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _connectionSubscription?.cancel();
    _messageController.dispose();
    // Only dispose if we created the controller ourselves
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return TRKRLoadingScreen(action: () {});
    }

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final colors = theme.extension<TRKRColors>();

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Support',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (!_isConnected)
                      Text(
                        'Connecting...',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                  ],
                ),
              ),
              if (_chatService.getUnreadCount() > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: colors?.vibrantAccent ?? Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_chatService.getUnreadCount()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Messages list
        Expanded(
          child: _messages.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FaIcon(
                        FontAwesomeIcons.message,
                        size: 48,
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No messages yet',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: Colors.grey.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Start a conversation with support',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    final isCurrentUser = _isCurrentUserMessage(message);

                    return _ChatMessageBubble(
                      message: message,
                      isCurrentUser: isCurrentUser,
                      timestamp: _formatTimestamp(message.createdAt),
                      isDarkMode: isDarkMode,
                      vibrantAccent: colors?.vibrantAccent ?? Colors.green,
                    );
                  },
                ),
        ),

        // Message input - simplified
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: _isConnected && !_isSending,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDarkMode ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(
                        color: Colors.grey.withValues(alpha: 0.5),
                      ),
                      filled: true,
                      fillColor: isDarkMode
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    maxLines: null,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 12),
                // Clean send button
                Material(
                  color: _isConnected && !_isSending
                      ? (colors?.vibrantAccent ?? Colors.green)
                      : Colors.grey,
                  borderRadius: BorderRadius.circular(24),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: _isConnected && !_isSending ? _sendMessage : null,
                    child: Container(
                      width: 48,
                      height: 48,
                      alignment: Alignment.center,
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const FaIcon(
                              FontAwesomeIcons.paperPlane,
                              color: Colors.white,
                              size: 18,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  final sendbird.RootMessage message;
  final bool isCurrentUser;
  final String timestamp;
  final bool isDarkMode;
  final Color vibrantAccent;

  const _ChatMessageBubble({
    required this.message,
    required this.isCurrentUser,
    required this.timestamp,
    required this.isDarkMode,
    required this.vibrantAccent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (message is sendbird.UserMessage) {
      final userMessage = message as sendbird.UserMessage;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          mainAxisAlignment:
              isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isCurrentUser) ...[
              // Avatar for other user
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: vibrantAccent.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    (message is sendbird.UserMessage &&
                            (message as sendbird.UserMessage)
                                    .sender
                                    ?.nickname
                                    .isNotEmpty ==
                                true)
                        ? (message as sendbird.UserMessage)
                            .sender!
                            .nickname
                            .substring(0, 1)
                            .toUpperCase()
                        : 'S',
                    style: TextStyle(
                      color: vibrantAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isCurrentUser
                      ? vibrantAccent
                      : (isDarkMode
                          ? Colors.grey.shade800
                          : Colors.grey.shade200),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(20),
                    topRight: const Radius.circular(20),
                    bottomLeft: isCurrentUser
                        ? const Radius.circular(20)
                        : const Radius.circular(4),
                    bottomRight: isCurrentUser
                        ? const Radius.circular(4)
                        : const Radius.circular(20),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isCurrentUser)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          (message is sendbird.UserMessage &&
                                  (message as sendbird.UserMessage)
                                          .sender
                                          ?.nickname
                                          .isNotEmpty ==
                                      true)
                              ? (message as sendbird.UserMessage)
                                  .sender!
                                  .nickname
                              : 'Support',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isCurrentUser
                                ? Colors.white.withValues(alpha: 0.9)
                                : vibrantAccent,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    Text(
                      userMessage.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isCurrentUser
                            ? Colors.white
                            : (isDarkMode ? Colors.white : Colors.black),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      timestamp,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isCurrentUser
                            ? Colors.white.withValues(alpha: 0.7)
                            : Colors.grey.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (isCurrentUser) ...[
              const SizedBox(width: 8),
              // Avatar for current user
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: vibrantAccent.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    'You',
                    style: TextStyle(
                      color: vibrantAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Handle other message types (file messages, etc.)
    return const SizedBox.shrink();
  }
}
