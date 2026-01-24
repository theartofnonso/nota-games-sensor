import 'dart:convert';

import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/chat_config.dart';
import '../../utils/theme/color_extensions.dart';
import '../../urls.dart';
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
  final TextEditingController _messageController = TextEditingController();
  late final ScrollController _scrollController;
  final List<ChatMessage> _messages = [];
  ChatConversation? _conversation;
  String? _currentUserId;
  String? _targetUserId;
  late final String _messageHandlerId;

  bool _isLoading = true;
  bool _isSending = false;
  static bool _isAgoraInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scrollController = widget.scrollController ?? ScrollController();
    _messageHandlerId = 'chat_screen_${DateTime.now().millisecondsSinceEpoch}';
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No user ID available. Please sign in again.');
      }
      _currentUserId = userId;
      _targetUserId = widget.clientUserId ?? widget.adminUserId;

      await _ensureAgoraInitialized();
      await _ensureAgoraLoggedIn(userId);
      await _loadConversationMessages();
      _registerMessageHandler();

      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
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

  Future<void> _refreshMessages() async {
    try {
      await _loadConversationMessages(append: true);
      if (!mounted) return;
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

  Future<void> _ensureAgoraInitialized() async {
    if (_isAgoraInitialized) return;
    if (ChatConfig.agoraAppKey.isEmpty) {
      throw Exception('Agora app key is not configured.');
    }
    final options = ChatOptions(
      appKey: ChatConfig.agoraAppKey,
      autoLogin: false,
    );
    await ChatClient.getInstance.init(options);
    _isAgoraInitialized = true;
  }

  Future<void> _ensureAgoraLoggedIn(String userId) async {
    if (ChatClient.getInstance.currentUserId == userId) {
      return;
    }
    final token = await _resolveAgoraToken(userId);
    if (token == null || token.isEmpty) {
      throw Exception('Agora chat token is not available.');
    }
    await ChatClient.getInstance.loginWithToken(userId, token);
  }

  Future<String?> _resolveAgoraToken(String userId) async {
    try {
      final uri = Uri.parse(agoraBaseUrl).resolve(agoraTokenPath);
      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': userId}),
      );
      if (response.statusCode != 200) {
        return null;
      }
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data['token'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _loadConversationMessages({bool append = false}) async {
    final targetUserId = _targetUserId;
    if (targetUserId == null) return;

    _conversation ??= await ChatClient.getInstance.chatManager.getConversation(
      targetUserId,
      type: ChatConversationType.Chat,
      createIfNeed: true,
    );

    final messages = await _conversation!.loadMessages(
      startMsgId: '',
      loadCount: 50,
      direction: ChatSearchDirection.Up,
    );

    if (!mounted) return;
    setState(() {
      for (final message in messages) {
        if (_messages.any((m) => m.msgId == message.msgId)) continue;
        _messages.add(message);
      }
      _sortMessages();
    });
  }

  void _registerMessageHandler() {
    ChatClient.getInstance.chatManager.addEventHandler(
      _messageHandlerId,
      ChatEventHandler(
        onMessagesReceived: (messages) {
          if (!mounted) return;
          setState(() {
            for (final message in messages) {
              if (_messages.any((m) => m.msgId == message.msgId)) continue;
              _messages.add(message);
            }
            _sortMessages();
          });
          _scrollToBottom();
        },
      ),
    );
  }

  void _sortMessages() {
    _messages
        .sort((a, b) => _messageTimestamp(a).compareTo(_messageTimestamp(b)));
  }

  DateTime _messageTimestamp(ChatMessage message) {
    final serverTime = message.serverTime;
    final localTime = message.localTime;
    final time =
        serverTime != 0 ? serverTime : (localTime != 0 ? localTime : 0);
    if (time == 0) {
      return DateTime.now();
    }
    return DateTime.fromMillisecondsSinceEpoch(time);
  }

  Future<void> _handleResume() async {
    final userId = _currentUserId;
    if (userId == null) {
      await _initializeChat();
      return;
    }
    try {
      await _ensureAgoraLoggedIn(userId);
      await _refreshMessages();
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isSending) return;
    final targetUserId = _targetUserId;
    if (targetUserId == null) return;

    if (!mounted) return;
    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final message = ChatMessage.createTxtSendMessage(
        targetId: targetUserId,
        content: messageText,
      );
      message.chatType = ChatType.Chat;
      await ChatClient.getInstance.chatManager.sendMessage(message);
      if (!mounted) return;
      setState(() {
        final isDuplicate = _messages.any((m) => m.msgId == message.msgId);
        if (!isDuplicate) {
          _messages.add(message);
          _sortMessages();
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
      _handleResume();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ChatClient.getInstance.chatManager.removeEventHandler(_messageHandlerId);
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

  bool _isCurrentUserMessage(ChatMessage message) {
    final currentUserId = _currentUserId;
    return message.from == currentUserId;
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
      final label = _dateBucketLabel(_messageTimestamp(message));
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
                      timestamp: _formatTimestamp(_messageTimestamp(message)),
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
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.delta.dy > 6) {
                  FocusScope.of(context).unfocus();
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDarkMode
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Stack(
                  children: [
                    TextField(
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
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.fromLTRB(
                          20,
                          12,
                          60,
                          12,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                    Positioned(
                      right: 8,
                      bottom: 8,
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: _isSending ? null : _sendMessage,
                            child: Container(
                              alignment: Alignment.center,
                              child: _isSending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                                Colors.white),
                                      ),
                                    )
                                  : FaIcon(
                                      FontAwesomeIcons.arrowUp,
                                      color: isDarkMode
                                          ? Colors.white
                                          : Colors.black,
                                      size: 16,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  final ChatMessage message;
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
                          _messageContent(message),
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
  final ChatMessage? message;
  final String? label;

  const _ChatListEntry.message(this.message) : label = null;
  const _ChatListEntry.divider(this.label) : message = null;

  bool get isDivider => label != null;
}

String _messageContent(ChatMessage message) {
  final body = message.body;
  if (body is ChatTextMessageBody) {
    return body.content;
  }
  return '';
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
