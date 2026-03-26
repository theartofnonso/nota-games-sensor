import 'dart:async';

import 'package:agora_chat_uikit/chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/screens/chat/chat_video_launcher.dart';
import 'package:trainware/services/chat_bootstrap_service.dart';
import 'package:trainware/services/chat_unread_counts_service.dart';
import 'package:trainware/services/chat_unread_service.dart';
import 'package:trainware/services/push_token_service.dart'
    show isNotificationPermissionGranted, requestNotificationPermission;
import 'package:trainware/utils/agora_chat_utils.dart';
import 'package:trainware/utils/general_utils.dart' show themeGradient;
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';

/// One-to-one chat using Agora Chat UI Kit (no custom message list / inbox).
class ChatScreen extends StatefulWidget {
  static const routeName = '/chat_screen';

  final String coachId;
  final String coachName;
  final String clientUserId;
  final String clientName;

  final ScrollController? scrollController;

  /// When true (e.g. embedded tab), hide back button on the kit app bar.
  final bool embeddedInShell;

  const ChatScreen({
    super.key,
    required this.coachId,
    required this.coachName,
    required this.clientUserId,
    required this.clientName,
    this.scrollController,
    this.embeddedInShell = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  bool _loading = true;
  String? _errorMessage;

  String get _peerSupabaseId =>
      AppConfig.isCoach ? widget.clientUserId : widget.coachId;

  String _peerDisplayName() {
    if (AppConfig.isCoach) {
      final n = widget.clientName.trim();
      return n.isNotEmpty ? n : 'Client';
    }
    final n = widget.coachName.trim();
    return n.isNotEmpty ? n : 'Coach';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_showNotificationPermissionSheetIfNeeded());
    unawaited(_prepareChat());
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clientUserId != widget.clientUserId ||
        oldWidget.coachId != widget.coachId) {
      setState(() {
        _loading = true;
        _errorMessage = null;
      });
      unawaited(_prepareChat());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final uid = Supabase.instance.client.auth.currentUser?.id;
      if (uid != null) {
        unawaited(ChatBootstrapService.ensureAgoraAndPushSetup(uid));
      }
    }
  }

  Future<void> _prepareChat() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null || userId.isEmpty) {
        throw Exception('No user ID available. Please sign in again.');
      }

      await ChatBootstrapService.ensureAgoraAndPushSetup(userId);

      if (!mounted) return;
      if (ChatUIKit.instance.currentUserId == null ||
          ChatUIKit.instance.currentUserId!.isEmpty) {
        throw Exception(
          'Could not connect to chat. Check your connection and try again.',
        );
      }

      final selfAgora = toAgoraUsername(userId);
      final peerAgora = toAgoraUsername(_peerSupabaseId);
      final name = _peerDisplayName();

      ChatUIKitProvider.instance.addProfiles([
        ChatUIKitProfile.contact(id: selfAgora, nickname: 'You'),
        ChatUIKitProfile.contact(id: peerAgora, nickname: name),
      ]);

      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = null;
      });
    } catch (e) {
      debugPrint('ChatScreen prepare error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _showNotificationPermissionSheetIfNeeded() async {
    if (await isNotificationPermissionGranted()) return;
    if (!mounted) return;
    await _presentNotificationPermissionSheet(context);
  }

  Future<void> _presentNotificationPermissionSheet(
    BuildContext sheetContext,
  ) async {
    await showAppActionBottomSheet<void>(
      context: sheetContext,
      isDismissible: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Get notified of new messages',
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              'Allow notifications to receive alerts when your coach or client sends you a message.',
              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                color: Theme.of(
                  sheetContext,
                ).colorScheme.onSurface.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OpacityButtonWidgetTwo(
                label: 'Enable notifications',
                buttonColor: Theme.of(sheetContext).colors.vibrantAccent,
                onPressed: () async {
                  await requestNotificationPermission();
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (AppConfig.isCoach) {
      ChatUnreadCountsService().refreshUnreadCountForClient(
        widget.clientUserId,
      );
    } else {
      unawaited(ChatUnreadService().refreshUnreadCount());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(gradient: themeGradient(context: context)),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(gradient: themeGradient(context: context)),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  OpacityButtonWidgetTwo(
                    label: 'Retry',
                    buttonColor: Theme.of(context).colors.vibrantAccent,
                    onPressed: () {
                      setState(() {
                        _loading = true;
                        _errorMessage = null;
                      });
                      unawaited(_prepareChat());
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final peerAgora = toAgoraUsername(_peerSupabaseId);
    final peerName = _peerDisplayName();

    final messages = MessagesView.arguments(
      MessagesViewArguments(
        profile: ChatUIKitProfile.contact(id: peerAgora, nickname: peerName),
        appBarModel: ChatUIKitAppBarModel(
          showBackButton: !widget.embeddedInShell,
          trailingActions: [
            ChatVideoLauncher.videoCallAppBarAction(
              coachId: widget.coachId,
              coachName: widget.coachName,
              clientUserId: widget.clientUserId,
              clientName: widget.clientName,
            ),
          ],
        ),
      ),
    );

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(gradient: themeGradient(context: context)),
      child: messages,
    );
  }
}
