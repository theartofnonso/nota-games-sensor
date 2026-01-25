import 'dart:convert';
import 'dart:io';

import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/theme/color_extensions.dart';
import '../../utils/agora_chat_utils.dart';
import '../../urls.dart';
import '../../app_flavor.dart';
import '../../services/chat_unread_service.dart';
import '../../services/chat_unread_counts_service.dart';
import '../../services/agora_chat_bootstrap.dart';
import '../../utils/uri_utils.dart';
import '../../widgets/bottom_sheets/app_bottom_sheet.dart';
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
  String? _currentAgoraUserId;
  String? _targetAgoraUserId;
  late final String _messageHandlerId;
  final Set<String> _attachmentDownloadsInFlight = {};

  bool _isLoading = true;
  bool _isSending = false;
  final ImagePicker _imagePicker = ImagePicker();

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
      _currentAgoraUserId = toAgoraUsername(userId);
      final targetUserId = widget.clientUserId ?? widget.adminUserId;
      _targetAgoraUserId = toAgoraUsername(targetUserId);

      await _ensureAgoraInitialized();
      await _ensureAgoraLoggedIn(_currentAgoraUserId!);
      await _loadConversationMessages();
      _registerMessageHandler();
      await _markConversationRead();
      _refreshUnreadBadges();

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
    await AgoraChatBootstrap.ensureInitialized();
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
    final targetAgoraUserId = _targetAgoraUserId;
    if (targetAgoraUserId == null) return;

    _conversation ??= await ChatClient.getInstance.chatManager.getConversation(
      targetAgoraUserId,
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
        _mergeMessage(message);
        _ensureAttachmentAvailable(message);
      }
      _sortMessages();
    });
    await _markConversationRead();
    _refreshUnreadBadges();
  }

  void _registerMessageHandler() {
    ChatClient.getInstance.chatManager.addEventHandler(
      _messageHandlerId,
      ChatEventHandler(
        onMessagesReceived: (messages) {
          if (!mounted) return;
          setState(() {
            for (final message in messages) {
              _mergeMessage(message);
              _ensureAttachmentAvailable(message);
            }
            _sortMessages();
          });
          _scrollToBottom();
        },
      ),
    );
  }

  void _sortMessages() {
    _messages.sort(
      (a, b) => _messageTimestamp(a).compareTo(_messageTimestamp(b)),
    );
  }

  void _mergeMessage(ChatMessage message) {
    final msgId = message.msgId;
    if (msgId.isNotEmpty) {
      final index = _messages.indexWhere((m) => m.msgId == msgId);
      if (index != -1) {
        _messages[index] = message;
        return;
      }
    }
    final index = _messages.indexWhere((m) => _isLikelyDuplicate(m, message));
    if (index != -1) {
      _messages[index] = message;
      return;
    }
    _messages.add(message);
  }

  void _ensureAttachmentAvailable(ChatMessage message) {
    final msgId = message.msgId;
    if (msgId.isEmpty) return;
    if (_attachmentDownloadsInFlight.contains(msgId)) return;

    final body = message.body;
    if (body is ChatImageMessageBody) {
      if (_attachmentImage(body) != null) return;
      _attachmentDownloadsInFlight.add(msgId);
      Future<void>(() async {
        await ChatClient.getInstance.chatManager.downloadThumbnail(message);
        if (body.localPath.isEmpty) {
          await ChatClient.getInstance.chatManager.downloadAttachment(message);
        }
      }).whenComplete(() {
        _attachmentDownloadsInFlight.remove(msgId);
        _refreshMessages();
      });
      return;
    }

    if (body is ChatVideoMessageBody) {
      if (_videoThumbnail(body) != null) return;
      _attachmentDownloadsInFlight.add(msgId);
      Future<void>(() async {
        await ChatClient.getInstance.chatManager.downloadThumbnail(message);
        if (body.localPath.isEmpty) {
          await ChatClient.getInstance.chatManager.downloadAttachment(message);
        }
      }).whenComplete(() {
        _attachmentDownloadsInFlight.remove(msgId);
        _refreshMessages();
      });
    }
  }

  bool _isLikelyDuplicate(ChatMessage existing, ChatMessage incoming) {
    if (existing.msgId.isNotEmpty &&
        incoming.msgId.isNotEmpty &&
        existing.msgId == incoming.msgId) {
      return true;
    }
    if (existing.from != incoming.from) return false;
    if (_messageContent(existing) != _messageContent(incoming)) return false;
    final delta = (_messageTimestamp(existing).millisecondsSinceEpoch -
            _messageTimestamp(incoming).millisecondsSinceEpoch)
        .abs();
    return delta <= 2000;
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

  Future<void> _markConversationRead() async {
    final conversation = _conversation;
    if (conversation == null) return;
    try {
      await conversation.markAllMessagesAsRead();
    } catch (_) {}
  }

  void _refreshUnreadBadges() {
    if (AppConfig.isCoach) {
      final clientId = widget.clientUserId;
      if (clientId != null) {
        ChatUnreadCountsService().refreshUnreadCountForClient(clientId);
      }
    } else {
      ChatUnreadService().refreshUnreadCount();
    }
  }

  Future<void> _handleResume() async {
    final userId = _currentAgoraUserId;
    if (userId == null) {
      await _initializeChat();
      return;
    }
    try {
      await _ensureAgoraLoggedIn(userId);
      await _refreshMessages();
      await _markConversationRead();
      _refreshUnreadBadges();
    } catch (_) {}
  }

  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty || _isSending) return;
    final targetAgoraUserId = _targetAgoraUserId;
    if (targetAgoraUserId == null) return;

    if (!mounted) return;
    setState(() => _isSending = true);
    _messageController.clear();

    try {
      final message = ChatMessage.createTxtSendMessage(
        targetId: targetAgoraUserId,
        content: messageText,
      );
      message.chatType = ChatType.Chat;
      await ChatClient.getInstance.chatManager.sendMessage(message);
      if (!mounted) return;
      setState(() {
        _mergeMessage(message);
        _sortMessages();
      });
      await _markConversationRead();
      _refreshUnreadBadges();
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

  Future<void> _showAttachmentSheet() async {
    await showAppBottomSheet<void>(
      context: context,
      isScrollControlled: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _ShareTile(
                    icon: Icons.photo,
                    label: 'Photo',
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _pickImage();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ShareTile(
                    icon: Icons.videocam,
                    label: 'Video',
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _pickVideo();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ShareTile(
                    icon: Icons.insert_drive_file,
                    label: 'File',
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _pickFile();
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final targetAgoraUserId = _targetAgoraUserId;
    if (targetAgoraUserId == null) return;
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    await _sendImageMessage(targetAgoraUserId, picked.path);
  }

  Future<void> _pickVideo() async {
    final targetAgoraUserId = _targetAgoraUserId;
    if (targetAgoraUserId == null) return;
    final picked = await _imagePicker.pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    await _sendVideoMessage(targetAgoraUserId, picked.path);
  }

  Future<void> _pickFile() async {
    final targetAgoraUserId = _targetAgoraUserId;
    if (targetAgoraUserId == null) return;
    final result = await FilePicker.platform.pickFiles();
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.path == null) return;
    await _sendFileMessage(targetAgoraUserId, file.path!);
  }

  Future<void> _sendImageMessage(String targetId, String path) async {
    try {
      final message = ChatMessage.createImageSendMessage(
        targetId: targetId,
        filePath: path,
      );
      message.chatType = ChatType.Chat;
      await ChatClient.getInstance.chatManager.sendMessage(message);
      if (!mounted) return;
      setState(() {
        _mergeMessage(message);
        _sortMessages();
      });
      _scrollToBottom();
    } catch (e) {
      _handleSendError(e, 'image');
    }
  }

  Future<void> _sendVideoMessage(String targetId, String path) async {
    try {
      final thumbnailPath = await _generateVideoThumbnail(path);
      final message = ChatMessage.createVideoSendMessage(
        targetId: targetId,
        filePath: path,
        thumbnailLocalPath: thumbnailPath,
      );
      message.chatType = ChatType.Chat;
      await ChatClient.getInstance.chatManager.sendMessage(message);
      if (!mounted) return;
      setState(() {
        _mergeMessage(message);
        _sortMessages();
      });
      _scrollToBottom();
    } catch (e) {
      _handleSendError(e, 'video');
    }
  }

  Future<String?> _generateVideoThumbnail(String path) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final thumbnail = await VideoThumbnail.thumbnailFile(
        video: path,
        thumbnailPath: tempDir.path,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 720,
        quality: 90,
      );
      return thumbnail;
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendFileMessage(String targetId, String path) async {
    try {
      final message = ChatMessage.createFileSendMessage(
        targetId: targetId,
        filePath: path,
      );
      message.chatType = ChatType.Chat;
      await ChatClient.getInstance.chatManager.sendMessage(message);
      if (!mounted) return;
      setState(() {
        _mergeMessage(message);
        _sortMessages();
      });
      _scrollToBottom();
    } catch (e) {
      _handleSendError(e, 'file');
    }
  }

  void _handleSendError(Object e, String label) {
    debugPrint('Error sending $label: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to send $label: $e'),
          backgroundColor: Colors.red,
        ),
      );
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
    final currentUserId = _currentAgoraUserId;
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
    final messageDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

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
                        (isDarkMode ? Colors.white : Colors.black).withValues(
                          alpha: 0.18,
                        ),
                        (isDarkMode ? Colors.white : Colors.black).withValues(
                          alpha: 0.05,
                        ),
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
                          'Start a conversation with your coach',
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
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
                          52,
                          12,
                          52,
                          12,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                    Positioned(
                      left: 8,
                      top: 8,
                      bottom: 8,
                      child: Align(
                        alignment: Alignment.center,
                        child: _ChatInputIconButton(
                          icon: Icons.add,
                          isDarkMode: isDarkMode,
                          onTap: _showAttachmentSheet,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 8,
                      bottom: 8,
                      child: Align(
                        alignment: Alignment.center,
                        child: _ChatInputIconButton(
                          icon: FontAwesomeIcons.arrowUp,
                          isDarkMode: isDarkMode,
                          onTap: _isSending ? null : _sendMessage,
                          isLoading: _isSending,
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
                      horizontal: 14,
                      vertical: 10,
                    ),
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
                        _MessageBody(message: message, textColor: textColor),
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

class _MessageBody extends StatelessWidget {
  final ChatMessage message;
  final Color textColor;

  const _MessageBody({required this.message, required this.textColor});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final body = message.body;
    if (body is ChatTextMessageBody) {
      return Text(
        body.content,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w400,
          fontSize: 16,
        ),
      );
    }

    if (body is ChatImageMessageBody) {
      final imageWidget = _attachmentImage(body);
      if (imageWidget == null) {
        return _AttachmentFallback(label: 'Image', textColor: textColor);
      }
      return GestureDetector(
        onTap: () => _openImageViewer(
          context,
          body.localPath,
          body.remotePath,
        ),
        child: imageWidget,
      );
    }

    if (body is ChatVideoMessageBody) {
      return _VideoAttachment(body: body, textColor: textColor);
    }

    if (body is ChatFileMessageBody) {
      return _AttachmentTile(
        icon: Icons.insert_drive_file,
        label: body.displayName ?? 'File',
        textColor: textColor,
        onTap: () => _openAttachment(context, body.remotePath),
      );
    }

    return Text(
      'Unsupported message',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: textColor,
        fontWeight: FontWeight.w400,
        fontSize: 16,
      ),
    );
  }
}

Widget? _attachmentImage(ChatImageMessageBody body) {
  if (body.localPath.isNotEmpty) {
    final file = File(body.localPath);
    if (file.existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(file, width: 220, height: 160, fit: BoxFit.cover),
      );
    }
  }
  final thumbLocal = body.thumbnailLocalPath;
  if (thumbLocal != null && thumbLocal.isNotEmpty) {
    final file = File(thumbLocal);
    if (file.existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          file,
          width: 220,
          height: 160,
          fit: BoxFit.cover,
        ),
      );
    }
  }
  if (body.thumbnailRemotePath != null &&
      body.thumbnailRemotePath!.isNotEmpty) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        body.thumbnailRemotePath!,
        width: 220,
        height: 160,
        fit: BoxFit.cover,
      ),
    );
  }
  if (body.remotePath != null && body.remotePath!.isNotEmpty) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        body.remotePath!,
        width: 220,
        height: 160,
        fit: BoxFit.cover,
      ),
    );
  }
  return null;
}

Future<void> _openAttachment(BuildContext context, String? remotePath) async {
  if (remotePath == null || remotePath.isEmpty) {
    return;
  }
  await openUrl(context: context, url: remotePath);
}

Future<void> _openImageViewer(
  BuildContext context,
  String? localPath,
  String? remotePath,
) async {
  if ((localPath == null || localPath.isEmpty) &&
      (remotePath == null || remotePath.isEmpty)) {
    return;
  }
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) {
      return _ImageViewerDialog(localPath: localPath, remotePath: remotePath);
    },
  );
}

class _AttachmentTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color textColor;
  final VoidCallback? onTap;

  const _AttachmentTile({
    required this.icon,
    required this.label,
    required this.textColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: textColor),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentFallback extends StatelessWidget {
  final String label;
  final Color textColor;

  const _AttachmentFallback({required this.label, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: textColor,
            fontWeight: FontWeight.w500,
          ),
    );
  }
}

class _ImageViewerDialog extends StatelessWidget {
  final String? localPath;
  final String? remotePath;

  const _ImageViewerDialog({required this.localPath, required this.remotePath});

  @override
  Widget build(BuildContext context) {
    final image = localPath != null && localPath!.isNotEmpty
        ? Image.file(File(localPath!), fit: BoxFit.contain)
        : Image.network(remotePath ?? '', fit: BoxFit.contain);
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(child: Center(child: image)),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoAttachment extends StatefulWidget {
  final ChatVideoMessageBody body;
  final Color textColor;

  const _VideoAttachment({required this.body, required this.textColor});

  @override
  State<_VideoAttachment> createState() => _VideoAttachmentState();
}

class _VideoAttachmentState extends State<_VideoAttachment> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  Future<void> _initController() async {
    final localPath = widget.body.localPath;
    final remotePath = widget.body.remotePath;
    if (localPath.isNotEmpty) {
      _controller = VideoPlayerController.file(File(localPath));
    } else if (remotePath != null && remotePath.isNotEmpty) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(remotePath));
    }
    if (_controller == null) return;
    await _controller!.initialize();
    if (!mounted) return;
    setState(() {
      _isInitialized = true;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final thumbnail = _videoThumbnail(widget.body);
    if (!_isInitialized && thumbnail != null) {
      return _ThumbnailPreview(
        thumbnail: thumbnail,
        textColor: widget.textColor,
        onTap: _playPause,
      );
    }

    if (_controller == null || !_isInitialized) {
      return _AttachmentFallback(label: 'Video', textColor: widget.textColor);
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(
            aspectRatio: _controller!.value.aspectRatio,
            child: VideoPlayer(_controller!),
          ),
          _PlayOverlay(
            isPlaying: _controller!.value.isPlaying,
            onTap: _playPause,
          ),
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(onTap: _openFullScreen),
            ),
          ),
        ],
      ),
    );
  }

  void _playPause() {
    final controller = _controller;
    if (controller == null) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  Future<void> _openFullScreen() async {
    final localPath = widget.body.localPath;
    final remotePath = widget.body.remotePath;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return _VideoViewerDialog(localPath: localPath, remotePath: remotePath);
      },
    );
  }
}

Widget? _videoThumbnail(ChatVideoMessageBody body) {
  final localThumb = body.thumbnailLocalPath;
  if (localThumb != null && localThumb.isNotEmpty) {
    final file = File(localThumb);
    if (file.existsSync()) {
      return Image.file(file, width: 220, height: 160, fit: BoxFit.cover);
    }
  }
  final remoteThumb = body.thumbnailRemotePath;
  if (remoteThumb != null && remoteThumb.isNotEmpty) {
    return Image.network(
      remoteThumb,
      width: 220,
      height: 160,
      fit: BoxFit.cover,
    );
  }
  return null;
}

class _ThumbnailPreview extends StatelessWidget {
  final Widget thumbnail;
  final Color textColor;
  final VoidCallback onTap;

  const _ThumbnailPreview({
    required this.thumbnail,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        alignment: Alignment.center,
        children: [
          thumbnail,
          _PlayOverlay(isPlaying: false, onTap: onTap),
        ],
      ),
    );
  }
}

class _PlayOverlay extends StatelessWidget {
  final bool isPlaying;
  final VoidCallback onTap;

  const _PlayOverlay({required this.isPlaying, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.2),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 28,
          ),
        ),
      ),
    );
  }
}

class _VideoViewerDialog extends StatefulWidget {
  final String? localPath;
  final String? remotePath;

  const _VideoViewerDialog({required this.localPath, required this.remotePath});

  @override
  State<_VideoViewerDialog> createState() => _VideoViewerDialogState();
}

class _VideoViewerDialogState extends State<_VideoViewerDialog> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    if (widget.localPath != null && widget.localPath!.isNotEmpty) {
      _controller = VideoPlayerController.file(File(widget.localPath!));
    } else if (widget.remotePath != null && widget.remotePath!.isNotEmpty) {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.remotePath!),
      );
    }
    if (_controller == null) return;
    await _controller!.initialize();
    if (!mounted) return;
    setState(() => _isInitialized = true);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: _isInitialized && _controller != null
                    ? AspectRatio(
                        aspectRatio: _controller!.value.aspectRatio,
                        child: VideoPlayer(_controller!),
                      )
                    : const CircularProgressIndicator(),
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
            if (_isInitialized && _controller != null)
              Center(
                child: _PlayOverlay(
                  isPlaying: _controller!.value.isPlaying,
                  onTap: () {
                    if (_controller!.value.isPlaying) {
                      _controller!.pause();
                    } else {
                      _controller!.play();
                    }
                    setState(() {});
                  },
                ),
              ),
          ],
        ),
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

class _ChatInputIconButton extends StatelessWidget {
  final IconData icon;
  final bool isDarkMode;
  final VoidCallback? onTap;
  final bool isLoading;

  const _ChatInputIconButton({
    required this.icon,
    required this.isDarkMode,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = isDarkMode
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.08);
    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    icon,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: 16,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ShareTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ShareTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final background = isDarkMode
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.05);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDarkMode
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.08),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withValues(alpha: 0.16)
                    : Colors.black.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isDarkMode ? Colors.white : Colors.black,
                size: 24,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

String _messageContent(ChatMessage message) {
  final body = message.body;
  if (body is ChatTextMessageBody) {
    return body.content;
  }
  if (body is ChatFileMessageBody) {
    return body.displayName ?? '';
  }
  if (body is ChatImageMessageBody) {
    return body.displayName ?? 'image';
  }
  if (body is ChatVideoMessageBody) {
    return body.displayName ?? 'video';
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
