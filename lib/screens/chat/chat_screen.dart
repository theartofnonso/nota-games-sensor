import 'dart:async';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import '../../services/chat_service.dart';
import '../../dtos/appsync/chat_message_dto.dart';
import '../../utils/theme/color_extensions.dart';
import '../../widgets/backgrounds/trkr_loading_screen.dart';

class ChatScreen extends StatefulWidget {
  static const routeName = '/chat_screen';

  /// Admin/Coach user ID for the one-to-one chat
  final String adminUserId;
  final String? clientUserId;
  final String? clientName;
  final String? clientEmail;

  /// Optional scroll controller for bottom sheet integration
  final ScrollController? scrollController;

  const ChatScreen({
    super.key,
    required this.adminUserId,
    this.clientUserId,
    this.clientName,
    this.clientEmail,
    this.scrollController,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  late final ScrollController _scrollController;
  final List<ChatMessageDto> _messages = [];

  bool _isLoading = true;
  bool _isSending = false;
  StreamSubscription<ChatMessageEvent>? _messageSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController = widget.scrollController ?? ScrollController();
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      // Get or create conversation
      if (widget.clientUserId != null) {
        final coachId = _chatService.currentUserId;
        if (coachId == null) {
          throw Exception('No coach ID available.');
        }
        await _chatService.getOrCreateConversation(
          coachId: coachId,
          userIdOverride: widget.clientUserId,
        );
      } else {
        await _chatService.getOrCreateConversation(
          coachId: widget.adminUserId,
        );
      }

      // Set up real-time message subscription
      _chatService.setupMessageSubscription();

      // Load previous messages
      final previousMessages =
          await _chatService.loadPreviousMessages(limit: 50);
      if (!mounted) return;
      setState(() {
        _messages.addAll(previousMessages);
        // Sort messages by timestamp in ascending order (oldest first, newest last)
        // Oldest messages at top, newest messages at bottom
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });

      // Set up message stream listener for real-time updates
      _messageSubscription = _chatService.messageStream.listen((event) {
        if (!mounted) return;

        setState(() {
          switch (event.type) {
            case ChatMessageEventType.insert:
              final message = event.message;
              if (message == null) return;
              if (_messages.any((m) => m.id == message.id)) return;
              _messages.add(message);
              break;
            case ChatMessageEventType.update:
              final message = event.message;
              if (message == null) return;
              final index = _messages.indexWhere((m) => m.id == message.id);
              if (index != -1) {
                _messages[index] = message;
              }
              break;
            case ChatMessageEventType.delete:
              final id = event.messageId;
              if (id == null) return;
              _messages.removeWhere((m) => m.id == id);
              break;
          }
          _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          _scrollToBottom();
          _chatService.markConversationAsRead();
        });
      });

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
      _chatService.markConversationAsRead();
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

  Future<void> _refreshMessages() async {
    try {
      final previousMessages =
          await _chatService.loadPreviousMessages(limit: 50);
      if (!mounted) return;
      setState(() {
        for (final message in previousMessages) {
          if (_messages.any((m) => m.id == message.id)) continue;
          _messages.add(message);
        }
        _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      });
      _scrollToBottom();
    } catch (e) {
      debugPrint('Error refreshing chat messages: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // Scroll to maxScrollExtent to show newest messages at bottom
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

    if (!mounted) return;
    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final sentMessage = await _chatService.sendMessage(messageText);
      // Add to local list if not already added by stream
      if (!mounted) return;
      setState(() {
        final isDuplicate = _messages.any((m) => m.id == sentMessage.id);
        if (!isDuplicate) {
          _messages.add(sentMessage);
          // Sort messages by timestamp in ascending order (oldest first, newest last)
          // Oldest messages at top, newest messages at bottom
          _messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        }
      });
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_chatService.currentConversationId == null) {
        _initializeChat();
        return;
      }
      _chatService.refreshMessageSubscription();
      _refreshMessages();
      _chatService.markConversationAsRead();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageSubscription?.cancel();
    _messageController.dispose();
    // Only dispose if we created the controller ourselves
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    super.dispose();
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('MMM d, HH:mm').format(dateTime);
    }
  }

  bool _isCurrentUserMessage(ChatMessageDto message) {
    final currentUserId = _chatService.currentUserId;
    return message.senderId == currentUserId;
  }

  String _initialsForName(String name, String? email) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return _initialsFromEmail(email);
    }
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.characters.take(2).toString().toUpperCase();
    }
    final first = parts.first.characters.first.toString().toUpperCase();
    final last = parts.last.characters.first.toString().toUpperCase();
    return '$first$last';
  }

  String _initialsFromEmail(String? email) {
    if (email == null || email.isEmpty) return '';
    final namePart = email.split('@').first;
    return namePart.characters.take(2).toString().toUpperCase();
  }

  List<_ChatListEntry> _buildChatEntries() {
    final entries = <_ChatListEntry>[];
    String? lastLabel;

    for (final message in _messages) {
      final label = _dateBucketLabel(message.createdAt);
      if (label != lastLabel) {
        entries.add(_ChatListEntry.divider(label));
        lastLabel = label;
      }
      entries.add(_ChatListEntry.message(message));
    }

    return entries;
  }

  String _dateBucketLabel(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate =
        DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (messageDate == today) {
      return 'Today';
    }
    if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday';
    }
    return DateFormat('EEEE, d MMM').format(messageDate);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return TRKRLoadingScreen(action: () {});
    }

    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final colors = theme.extension<TRKRColors>();

    final showClientHeader =
        widget.clientUserId != null && widget.clientName != null;
    final clientInitials = showClientHeader
        ? _initialsForName(widget.clientName!, widget.clientEmail)
        : null;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              if (showClientHeader && clientInitials != null) ...[
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        (isDarkMode ? Colors.white : Colors.black)
                            .withValues(alpha: 0.18),
                        (isDarkMode ? Colors.white : Colors.black)
                            .withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    clientInitials,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      showClientHeader ? widget.clientName! : 'Check In',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                    ),
                    if (showClientHeader) const SizedBox.shrink(),
                  ],
                ),
              ),
              // Close button
              IconButton(
                icon: FaIcon(
                  FontAwesomeIcons.solidCircleXmark,
                  color: isDarkMode ? Colors.white : Colors.black,
                  size: 20,
                ),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),

        // Messages list
        Expanded(
          child: _messages.isEmpty
              ? GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: Center(
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
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a conversation with support',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey.withValues(alpha: 0.5),
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.manual,
                  itemCount: _buildChatEntries().length,
                  itemBuilder: (context, index) {
                    final entries = _buildChatEntries();
                    final entry = entries[index];

                    if (entry.isDivider) {
                      return _ChatDateDivider(label: entry.label!);
                    }

                    final message = entry.message!;
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
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    enabled: !_isSending,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type a message...',
                      hintStyle: TextStyle(
                        color: Colors.grey.withValues(alpha: 0.5),
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                      filled: true,
                      fillColor: isDarkMode
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.black.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.2)
                              : Colors.black.withValues(alpha: 0.2),
                          width: 1,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: isDarkMode
                              ? Colors.white.withValues(alpha: 0.4)
                              : Colors.black.withValues(alpha: 0.4),
                          width: 1,
                        ),
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
                // Send button - no background, with border
                SizedBox(
                  width: 48,
                  height: 48,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: _isSending ? null : _sendMessage,
                      child: Container(
                        alignment: Alignment.center,
                        child: _isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : FaIcon(
                                FontAwesomeIcons.arrowUp,
                                color: isDarkMode ? Colors.white : Colors.black,
                                size: 18,
                              ),
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
  final ChatMessageDto message;
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
    final outgoingColor = Colors.white;
    final incomingColor = Colors.black;
    final bubbleColor = isCurrentUser ? outgoingColor : incomingColor;
    final textColor = isCurrentUser ? Colors.black : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxBubbleWidth = constraints.maxWidth * 0.75;
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: 100,
                    maxWidth: maxBubbleWidth,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isCurrentUser ? 18 : 4),
                        bottomRight: Radius.circular(isCurrentUser ? 4 : 18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.content,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: textColor,
                            fontWeight: FontWeight.w400,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          timestamp,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: textColor.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatListEntry {
  final ChatMessageDto? message;
  final String? label;

  const _ChatListEntry.message(this.message) : label = null;
  const _ChatListEntry.divider(this.label) : message = null;

  bool get isDivider => label != null;
}

class _ChatDateDivider extends StatelessWidget {
  final String label;

  const _ChatDateDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.black.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
