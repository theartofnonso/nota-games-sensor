import 'dart:async';

import 'package:agora_chat_uikit/chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/screens/chat/chat_video_launcher.dart';
import 'package:trainware/services/chat_bootstrap_service.dart';
import 'package:trainware/services/chat_unread_counts_service.dart';
import 'package:trainware/services/chat_unread_service.dart';
import 'package:trainware/utils/agora_chat_utils.dart';
import 'package:trainware/utils/general_utils.dart' show themeGradient;
import 'package:trainware/utils/theme/chat_uikit_trainware_theme.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
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

      await ChatBootstrapService.ensurePeerChatHistoryLoaded(peerAgora);
      if (!mounted) return;

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

    return MessagesView.arguments(
      MessagesViewArguments(
        profile: ChatUIKitProfile.contact(id: peerAgora, nickname: peerName),
        backgroundWidget: trainwareChatBackground(context),
        bubbleBuilder: trainwareChatBubbleBuilder,
        showMessageItemAvatar: (_) => false,
        appBarModel: ChatUIKitAppBarModel(
          leadingActions: const <ChatUIKitAppBarAction>[],
          showBackButton: !widget.embeddedInShell,
          backgroundColor: Colors.transparent,
          bottomLine: false,
          systemOverlayStyle: Theme.of(context).brightness == Brightness.dark
              ? SystemUiOverlayStyle.light
              : SystemUiOverlayStyle.dark,
          trailingActions: [
            if (AppConfig.supportsVideoCalls)
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
  }
}
