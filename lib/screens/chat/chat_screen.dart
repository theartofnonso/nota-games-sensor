import 'dart:async';
import 'dart:io';

import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/theme/color_extensions.dart';
import '../../utils/agora_chat_utils.dart';
import '../../services/chat_bootstrap_service.dart';
import '../../app_flavor.dart';
import '../../services/chat_unread_service.dart';
import '../../services/chat_unread_counts_service.dart';
import '../../services/push_token_service.dart'
    show
        isNotificationPermissionGranted,
        requestNotificationPermission,
        setupPushToken;
import '../../utils/dialog_utils.dart';
import '../../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../../widgets/buttons/opacity_button_widget_two.dart';
import '../../widgets/chat/chat_layout.dart';
import '../video/video_call_screen.dart';

class ChatScreen extends StatefulWidget {
  static const routeName = '/chat_screen';

  /// Coach user ID for the one-to-one chat
  final String coachId;
  final String coachName;
  final String clientUserId;
  final String clientName;

  /// Optional scroll controller for bottom sheet integration
  final ScrollController? scrollController;

  const ChatScreen({
    super.key,
    required this.coachId,
    required this.coachName,
    required this.clientUserId,
    required this.clientName,
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
  String? _supabaseUserId;
  String? _currentAgoraUserId;
  String? _targetAgoraUserId;
  late final String _messageHandlerId;
  final Set<String> _attachmentDownloadsInFlight = {};

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

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clientUserId != widget.clientUserId ||
        oldWidget.coachId != widget.coachId) {
      _conversation = null;
      _targetAgoraUserId = toAgoraUsername(_targetUserId());
      _messages.clear();
      _initializeChat();
    }
  }

  Future<void> _initializeChat() async {
    try {
      if (!mounted) return;

      // Show permission bottom sheet if not yet granted; CTA triggers the request
      unawaited(_showNotificationPermissionSheetIfNeeded());

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('No user ID available. Please sign in again.');
      }
      _supabaseUserId = userId;
      _currentAgoraUserId = toAgoraUsername(userId);
      _targetAgoraUserId = toAgoraUsername(_targetUserId());

      // Login first; cache load requires logged-in user (201 otherwise)
      unawaited(_loginAndFetchMessages());
    } catch (e) {
      debugPrint('Error initializing chat: $e');
      if (mounted) {
        showErrorBottomSheet(
          context: context,
          message: 'Failed to initialize chat: $e',
        );
      }
    }
  }

  Future<void> _openVideoCall() async {
    final cameraGranted = await Permission.camera.isGranted;
    final micGranted = await Permission.microphone.isGranted;
    if (cameraGranted && micGranted) {
      _pushVideoCallScreen();
      return;
    }
    if (!mounted) return;
    await showAppActionBottomSheet<void>(
      context: context,
      isDismissible: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Camera and microphone access',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Allow access to your camera and microphone to make video calls with your coach or client.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.8),
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OpacityButtonWidgetTwo(
                label: 'Allow',
                buttonColor: Theme.of(context).colors.vibrantAccent,
                onPressed: () async {
                  final statuses = await [
                    Permission.camera,
                    Permission.microphone,
                  ].request();
                  if (!context.mounted) return;
                  Navigator.of(context).pop();
                  if (statuses[Permission.camera] == PermissionStatus.granted &&
                      statuses[Permission.microphone] ==
                          PermissionStatus.granted) {
                    _pushVideoCallScreen();
                  } else {
                    showErrorBottomSheet(
                      context: context,
                      message:
                          'Camera and microphone access is required for video calls.',
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _pushVideoCallScreen() {
    Navigator.of(context).push(
      PageRouteBuilder(
        fullscreenDialog: true,
        opaque: true,
        pageBuilder: (_, __, ___) => VideoCallScreen(
          targetUserId: _targetUserId(),
        ),
        transitionsBuilder: (_, animation, __, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween =
              Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  /// Show a bottom sheet explaining why we need notification permission.
  /// CTA triggers the actual request. Only shown if permission not yet granted.
  Future<void> _showNotificationPermissionSheetIfNeeded() async {
    if (await isNotificationPermissionGranted()) return;
    if (!mounted) return;

    await showAppActionBottomSheet<void>(
      context: context,
      isDismissible: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Get notified of new messages',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            Text(
              'Allow notifications to receive alerts when your coach or client sends you a message.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.8),
                  ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OpacityButtonWidgetTwo(
                label: 'Enable notifications',
                buttonColor: Theme.of(context).colors.vibrantAccent,
                onPressed: () async {
                  await requestNotificationPermission();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Login, then load cache + fetch messages. Cache requires login (201 otherwise).
  Future<void> _loginAndFetchMessages() async {
    try {
      final supabaseUserId = _supabaseUserId;
      if (supabaseUserId == null) return;

      await _ensureAgoraLoggedIn(supabaseUserId);

      // Load cached messages only after login (getConversation/loadMessages require login)
      await _loadCachedMessages();
      if (!mounted) return;
      _scrollToBottom();

      // Ensure conversation exists (create if needed)
      final targetAgoraUserId = _targetAgoraUserId;
      if (targetAgoraUserId != null && _conversation == null) {
        _conversation =
            await ChatClient.getInstance.chatManager.getConversation(
          targetAgoraUserId,
          type: ChatConversationType.Chat,
          createIfNeed: true,
        );
      }

      _registerMessageHandler();

      await _fetchRecentMessagesFromServer();
      await _markConversationRead();
      _refreshUnreadBadges();
    } catch (e) {
      debugPrint('Error during background login/fetch: $e');
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

  /// Ensure user is logged in. Login happens once when chat opens.
  /// [supabaseUserId] is the raw auth user id; backend derives Agora username for the token.
  Future<void> _ensureAgoraLoggedIn(String supabaseUserId) async {
    final agoraUserId = toAgoraUsername(supabaseUserId);
    // Check if already logged in as the correct user
    if (ChatClient.getInstance.currentUserId == agoraUserId) {
      return;
    }

    final token =
        await ChatBootstrapService.resolveAgoraChatToken(supabaseUserId);
    if (token == null || token.isEmpty) {
      throw Exception('Agora chat token is not available.');
    }

    try {
      await ChatClient.getInstance.loginWithToken(agoraUserId, token);
      // Verify login succeeded
      if (ChatClient.getInstance.currentUserId != agoraUserId) {
        throw Exception('Login verification failed. Please try again.');
      }

      // Token upload requires a logged-in user; call only after login completes.
      await setupPushToken();
    } catch (e) {
      debugPrint('Agora Chat login error: $e');
      // Re-throw to be handled by caller
      rethrow;
    }
  }

  /// Load cached messages from local DB. Must be called after Agora login (201 otherwise).
  /// Uses createIfNeed: true so we always have a conversation and load (cached or empty).
  Future<void> _loadCachedMessages() async {
    final targetAgoraUserId = _targetAgoraUserId;
    if (targetAgoraUserId == null) return;

    try {
      _conversation ??=
          await ChatClient.getInstance.chatManager.getConversation(
        targetAgoraUserId,
        type: ChatConversationType.Chat,
        createIfNeed: true,
      );

      if (_conversation == null) return;

      final messages = await _conversation!.loadMessages(
        startMsgId: '',
        loadCount: 10000, // Load all cached messages
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
    } catch (e) {
      debugPrint('Error loading cached messages: $e');
    }
  }

  /// Fetch recent messages from server in background (non-blocking)
  /// Called after login completes - no need to check login state
  Future<void> _fetchRecentMessagesFromServer() async {
    final targetAgoraUserId = _targetAgoraUserId;
    if (targetAgoraUserId == null) return;

    try {
      // Fetch all messages from server (using large pageSize to load all)
      final cursorResult =
          await ChatClient.getInstance.chatManager.fetchHistoryMessagesByOption(
        targetAgoraUserId,
        ChatConversationType.Chat,
        options: const FetchMessageOptions(
          direction: ChatSearchDirection.Up,
          needSave: true, // Save to local DB for future cache hits
        ),
        pageSize: 10000, // Load all messages
      );
      final serverMessages = cursorResult.data;

      if (!mounted) return;

      // Check if we got any new messages
      bool hasNewMessages = false;
      for (final message in serverMessages) {
        final existingIndex =
            _messages.indexWhere((m) => m.msgId == message.msgId);
        if (existingIndex == -1) {
          hasNewMessages = true;
          break;
        }
      }

      if (hasNewMessages) {
        setState(() {
          for (final message in serverMessages) {
            _mergeMessage(message);
            _ensureAttachmentAvailable(message);
          }
          _sortMessages();
        });
        _scrollToBottom();
        _refreshUnreadBadges();
      }
      // Always refresh UI after fetch so list reflects current _messages (e.g. after first load)
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Error fetching chat history from server: $e');
      // Silently fail - cached messages are already shown
      if (mounted) setState(() {});
    }
  }

  /// Legacy method for refreshing messages (used by pull-to-refresh, etc.)
  Future<void> _loadConversationMessages({bool append = false}) async {
    // For refresh scenarios, still fetch from server
    await _fetchRecentMessagesFromServer();
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

  bool _hasLocalAttachment(ChatMessage message) {
    final body = message.body;
    if (body is ChatImageMessageBody) {
      return body.localPath.isNotEmpty && File(body.localPath).existsSync();
    }
    if (body is ChatVideoMessageBody) {
      return body.localPath.isNotEmpty && File(body.localPath).existsSync();
    }
    return false;
  }

  void _mergeMessage(ChatMessage message) {
    final msgId = message.msgId;
    if (msgId.isNotEmpty) {
      final index = _messages.indexWhere((m) => m.msgId == msgId);
      if (index != -1) {
        final existing = _messages[index];
        // Don't overwrite with server message if we have downloaded local data
        // (server messages don't include localPath; we'd lose playable video/image)
        if (_hasLocalAttachment(existing) && !_hasLocalAttachment(message)) {
          return;
        }
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
      // Check if we already have the image available
      final hasLocal =
          body.localPath.isNotEmpty && File(body.localPath).existsSync();
      final hasThumbLocal = body.thumbnailLocalPath != null &&
          body.thumbnailLocalPath!.isNotEmpty &&
          File(body.thumbnailLocalPath!).existsSync();
      final hasThumbRemote = body.thumbnailRemotePath != null &&
          body.thumbnailRemotePath!.isNotEmpty;

      // If we have at least a thumbnail, we can show something
      if (hasLocal || hasThumbLocal || hasThumbRemote) {
        // Still try to download full quality in background if not available
        if (!hasLocal &&
            body.remotePath != null &&
            body.remotePath!.isNotEmpty) {
          if (_attachmentDownloadsInFlight.contains(msgId)) return;
          _attachmentDownloadsInFlight.add(msgId);
          Future<void>(() async {
            await ChatClient.getInstance.chatManager
                .downloadAttachment(message);
          }).whenComplete(() {
            _attachmentDownloadsInFlight.remove(msgId);
            if (mounted) setState(() {});
          });
        }
        return;
      }

      // No image available at all - download thumbnail first
      if (_attachmentDownloadsInFlight.contains(msgId)) return;
      _attachmentDownloadsInFlight.add(msgId);
      Future<void>(() async {
        await ChatClient.getInstance.chatManager.downloadThumbnail(message);
        if (body.localPath.isEmpty) {
          await ChatClient.getInstance.chatManager.downloadAttachment(message);
        }
      }).whenComplete(() {
        _attachmentDownloadsInFlight.remove(msgId);
        if (mounted) setState(() {});
      });
      return;
    }

    if (body is ChatVideoMessageBody) {
      // For video: we need local file to play reliably (network playback may fail
      // with Agora CDN). Trigger download if we don't have local video yet.
      final hasLocalVideo =
          body.localPath.isNotEmpty && File(body.localPath).existsSync();
      if (hasLocalVideo) return;

      _attachmentDownloadsInFlight.add(msgId);
      Future<void>(() async {
        await ChatClient.getInstance.chatManager.downloadThumbnail(message);
        if (body.localPath.isEmpty) {
          await ChatClient.getInstance.chatManager.downloadAttachment(message);
        }
      }).whenComplete(() {
        _attachmentDownloadsInFlight.remove(msgId);
        if (mounted) setState(() {});
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
    } catch (e) {
      debugPrint('Error marking conversation as read: $e');
    }
  }

  void _refreshUnreadBadges() {
    if (AppConfig.isCoach) {
      final clientId = widget.clientUserId;
      ChatUnreadCountsService().refreshUnreadCountForClient(clientId);
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
    // Just refresh messages - login was done once at start
    try {
      await _refreshMessages();
      await _markConversationRead();
      _refreshUnreadBadges();
    } catch (e) {
      debugPrint('Error resuming chat: $e');
    }
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
        showErrorBottomSheet(
          context: context,
          message: 'Failed to send message: $e',
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

  void _handleSendError(Object e, String label) {
    debugPrint('Error sending $label: $e');
    if (mounted) {
      showErrorBottomSheet(
        context: context,
        message: 'Failed to send $label: $e',
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
    if (widget.scrollController == null) {
      _scrollController.dispose();
    }
    // So coach list shows updated unread when returning from this chat
    if (AppConfig.isCoach) {
      ChatUnreadCountsService()
          .refreshUnreadCountForClient(widget.clientUserId);
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

  String _clientInitials() {
    final trimmed = widget.clientName.trim();
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final s = parts.first;
      return s.substring(0, s.length.clamp(0, 2)).toUpperCase();
    }
    final first = parts.first[0].toString().toUpperCase();
    final last = parts.last[0].toString().toUpperCase();
    return '$first$last';
  }

  String _coachInitials() {
    final trimmed = widget.coachName.trim();
    return trimmed[0].toUpperCase();
  }

  /// Returns the target user ID based on app configuration.
  /// - Coach app: returns clientUserId (coach viewing client)
  /// - Client app: returns coachId (client viewing coach)
  String _targetUserId() {
    return AppConfig.isCoach ? widget.clientUserId : widget.coachId;
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
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final colors = theme.extension<TRKRColors>();
    final displayInitials =
        AppConfig.isCoach ? _clientInitials() : _coachInitials();

    final headerLeading = displayInitials.isNotEmpty
        ? Container(
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
              displayInitials,
              style: theme.textTheme.labelLarge?.copyWith(
                color: isDarkMode ? Colors.white : Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        : const SizedBox(width: 36, height: 36);

    return ChatLayout(
      headerLeading: headerLeading,
      title:
          AppConfig.isCoach ? widget.clientName : 'Coach ${widget.coachName}',
      headerActions: [
        IconButton(
          icon: Icon(Icons.videocam,
              color: isDarkMode ? Colors.white : Colors.black, size: 22),
          onPressed: () => _openVideoCall(),
        ),
        IconButton(
          icon: Icon(
            FontAwesomeIcons.solidCircleXmark,
            color: isDarkMode ? Colors.white : Colors.black,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
      messagesContent: _messages.isEmpty
          ? ChatEmptyState(
              title: 'No messages yet',
              subtitle: AppConfig.isCoach
                  ? 'Start a conversation with your client'
                  : 'Start a conversation with your coach',
            )
          : Builder(
              builder: (context) {
                final entries = _buildChatEntries();
                return ListView.builder(
                  controller: _scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.manual,
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    if (entry.isDivider) {
                      return _ChatDateDivider(label: entry.label!);
                    }
                    final message = entry.message!;
                    return _ChatMessageBubble(
                      message: message,
                      isCurrentUser: _isCurrentUserMessage(message),
                      timestamp: _formatTimestamp(_messageTimestamp(message)),
                      isDarkMode: isDarkMode,
                      vibrantAccent: colors?.vibrantAccent ?? Colors.green,
                    );
                  },
                );
              },
            ),
      messageController: _messageController,
      onSend: _sendMessage,
      isSending: _isSending,
      showAttachmentButton: true,
      onAttachmentTap: _showAttachmentSheet,
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
      return GestureDetector(
        onTap: () => _openImageViewer(
          context,
          body,
        ),
        child: _ProgressiveImageWidget(body: body),
      );
    }

    if (body is ChatVideoMessageBody) {
      return _VideoAttachment(body: body, textColor: textColor);
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

/// Progressive image widget that shows thumbnail first, then loads full quality
class _ProgressiveImageWidget extends StatefulWidget {
  final ChatImageMessageBody body;

  const _ProgressiveImageWidget({required this.body});

  @override
  State<_ProgressiveImageWidget> createState() =>
      _ProgressiveImageWidgetState();
}

class _ProgressiveImageWidgetState extends State<_ProgressiveImageWidget> {
  bool _hasFullQuality = false;

  @override
  void initState() {
    super.initState();
    _loadFullQualityInBackground();
  }

  void _loadFullQualityInBackground() {
    // Check if we already have full quality local image
    if (widget.body.localPath.isNotEmpty) {
      final file = File(widget.body.localPath);
      if (file.existsSync()) {
        setState(() {
          _hasFullQuality = true;
        });
        return;
      }
    }

    // Load full quality remote image in background
    if (widget.body.remotePath != null && widget.body.remotePath!.isNotEmpty) {
      // Precache the image to load it in background
      precacheImage(
        NetworkImage(widget.body.remotePath!),
        context,
      ).then((_) {
        if (!mounted) return;
        setState(() {
          _hasFullQuality = true;
        });
      }).catchError((_) {
        // Silently fail - keep showing thumbnail
      });
    }
  }

  ImageProvider? _getThumbnailProvider() {
    // Try local thumbnail first
    final thumbLocal = widget.body.thumbnailLocalPath;
    if (thumbLocal != null && thumbLocal.isNotEmpty) {
      final file = File(thumbLocal);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }

    // Fall back to remote thumbnail
    if (widget.body.thumbnailRemotePath != null &&
        widget.body.thumbnailRemotePath!.isNotEmpty) {
      return NetworkImage(widget.body.thumbnailRemotePath!);
    }

    return null;
  }

  ImageProvider? _getFullQualityProvider() {
    if (widget.body.localPath.isNotEmpty) {
      final file = File(widget.body.localPath);
      if (file.existsSync()) {
        return FileImage(file);
      }
    }

    if (widget.body.remotePath != null && widget.body.remotePath!.isNotEmpty) {
      return NetworkImage(widget.body.remotePath!);
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final thumbnailProvider = _getThumbnailProvider();
    final fullQualityProvider = _getFullQualityProvider();

    // If no thumbnail or full quality available, show placeholder
    if (thumbnailProvider == null && fullQualityProvider == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: const SizedBox(
          width: 220,
          height: 160,
          child: Center(
            child: Icon(Icons.image, color: Colors.grey),
          ),
        ),
      );
    }

    // If we have full quality loaded, show it with smooth fade-in transition
    if (_hasFullQuality &&
        fullQualityProvider != null &&
        thumbnailProvider != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: FadeInImage(
          placeholder: thumbnailProvider,
          image: fullQualityProvider,
          width: 220,
          height: 160,
          fit: BoxFit.cover,
          fadeInDuration: const Duration(milliseconds: 300),
          fadeOutDuration: const Duration(milliseconds: 100),
          imageErrorBuilder: (context, error, stackTrace) {
            // If full quality fails, show thumbnail
            return Image(
              image: thumbnailProvider,
              width: 220,
              height: 160,
              fit: BoxFit.cover,
            );
          },
        ),
      );
    }

    // If we have full quality but no thumbnail, show full quality directly
    if (_hasFullQuality &&
        fullQualityProvider != null &&
        thumbnailProvider == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image(
          image: fullQualityProvider,
          width: 220,
          height: 160,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox(
              width: 220,
              height: 160,
              child: Center(
                child: Icon(Icons.image, color: Colors.grey),
              ),
            );
          },
        ),
      );
    }

    // Show thumbnail while loading full quality in background
    if (thumbnailProvider != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image(
          image: thumbnailProvider,
          width: 220,
          height: 160,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox(
              width: 220,
              height: 160,
              child: Center(
                child: Icon(Icons.image, color: Colors.grey),
              ),
            );
          },
        ),
      );
    }

    // Fallback placeholder
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: const SizedBox(
        width: 220,
        height: 160,
        child: Center(
          child: Icon(Icons.image, color: Colors.grey),
        ),
      ),
    );
  }
}

Future<void> _openImageViewer(
  BuildContext context,
  ChatImageMessageBody body,
) async {
  // Check if we have any image source available
  final hasLocal =
      body.localPath.isNotEmpty && File(body.localPath).existsSync();
  final hasRemote = body.remotePath != null && body.remotePath!.isNotEmpty;
  final hasThumbLocal = body.thumbnailLocalPath != null &&
      body.thumbnailLocalPath!.isNotEmpty &&
      File(body.thumbnailLocalPath!).existsSync();
  final hasThumbRemote =
      body.thumbnailRemotePath != null && body.thumbnailRemotePath!.isNotEmpty;

  if (!hasLocal && !hasRemote && !hasThumbLocal && !hasThumbRemote) {
    return;
  }

  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) {
      return _ImageViewerDialog(body: body);
    },
  );
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

class _ImageViewerDialog extends StatefulWidget {
  final ChatImageMessageBody body;

  const _ImageViewerDialog({required this.body});

  @override
  State<_ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<_ImageViewerDialog> {
  Widget? _imageWidget;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Priority 1: Full quality local image
    if (widget.body.localPath.isNotEmpty) {
      final file = File(widget.body.localPath);
      if (file.existsSync()) {
        setState(() {
          _imageWidget = Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorWidget();
            },
          );
          _isLoading = false;
        });
        return;
      }
    }

    // Priority 2: Full quality remote image
    if (widget.body.remotePath != null && widget.body.remotePath!.isNotEmpty) {
      setState(() {
        _imageWidget = Image.network(
          widget.body.remotePath!,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              setState(() => _isLoading = false);
              return child;
            }
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            setState(() {
              _isLoading = false;
              _error = 'Failed to load image';
            });
            return _buildErrorWidget();
          },
        );
      });
      return;
    }

    // Priority 3: Local thumbnail
    if (widget.body.thumbnailLocalPath != null &&
        widget.body.thumbnailLocalPath!.isNotEmpty) {
      final file = File(widget.body.thumbnailLocalPath!);
      if (file.existsSync()) {
        setState(() {
          _imageWidget = Image.file(
            file,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return _buildErrorWidget();
            },
          );
          _isLoading = false;
        });
        return;
      }
    }

    // Priority 4: Remote thumbnail
    if (widget.body.thumbnailRemotePath != null &&
        widget.body.thumbnailRemotePath!.isNotEmpty) {
      setState(() {
        _imageWidget = Image.network(
          widget.body.thumbnailRemotePath!,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) {
              setState(() => _isLoading = false);
              return child;
            }
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            setState(() {
              _isLoading = false;
              _error = 'Failed to load image';
            });
            return _buildErrorWidget();
          },
        );
      });
      return;
    }

    setState(() {
      _isLoading = false;
      _error = 'No image available';
    });
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 48),
          const SizedBox(height: 16),
          Text(
            _error ?? 'Failed to load image',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
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
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : _imageWidget != null
                      ? InteractiveViewer(
                          child: Center(child: _imageWidget),
                        )
                      : _buildErrorWidget(),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
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
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
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
