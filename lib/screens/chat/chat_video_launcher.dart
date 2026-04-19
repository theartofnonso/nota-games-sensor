import 'package:agora_chat_uikit/chat_uikit.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/repositories/supabase/supabase_coaches_repository.dart';
import 'package:trainware/services/fcm_push_service.dart';
import 'package:trainware/utils/dialog_utils.dart';

import '../video/outgoing_call_screen.dart';
import '../video/video_call_screen.dart';

/// Video call flow extracted from chat (Agora RTC), independent of chat UI kit.
class ChatVideoLauncher {
  ChatVideoLauncher._();

  /// Raw Supabase user id of the person you're calling (coach or client).
  static String targetSupabaseUserId({
    required String coachId,
    required String clientUserId,
  }) {
    return AppConfig.isCoach ? clientUserId : coachId;
  }

  static String _targetDisplayName({
    required String coachName,
    required String clientName,
  }) {
    if (AppConfig.isCoach) {
      final trimmed = clientName.trim();
      return trimmed.isNotEmpty ? trimmed : 'Client';
    }
    final trimmed = coachName.trim();
    return trimmed.isNotEmpty ? trimmed : 'Coach';
  }

  static String _notifyCallerNameWhenClient({
    required String clientName,
  }) {
    final trimmed = clientName.trim();
    return trimmed.isNotEmpty ? trimmed : 'Client';
  }

  static Future<void> openVideoCall(
    BuildContext context, {
    required String coachId,
    required String coachName,
    required String clientUserId,
    required String clientName,
  }) async {
    if (!AppConfig.supportsVideoCalls) return;
    await _pushVideoCallScreen(
      context,
      coachId: coachId,
      coachName: coachName,
      clientUserId: clientUserId,
      clientName: clientName,
    );
  }

  static Future<void> _pushVideoCallScreen(
    BuildContext context, {
    required String coachId,
    required String coachName,
    required String clientUserId,
    required String clientName,
  }) async {
    final callerId = Supabase.instance.client.auth.currentUser?.id;
    final calleeId = targetSupabaseUserId(
      coachId: coachId,
      clientUserId: clientUserId,
    );
    final targetDisplayName = _targetDisplayName(
      coachName: coachName,
      clientName: clientName,
    );

    if (!context.mounted) return;
    final nav = Navigator.of(context);
    var outgoingCancelled = false;

    late final Route<void> outgoingRoute;
    outgoingRoute = PageRouteBuilder<void>(
      settings: const RouteSettings(name: 'outgoing_call'),
      opaque: true,
      fullscreenDialog: true,
      pageBuilder: (ctx, animation, secondaryAnimation) => OutgoingCallScreen(
        calleeName: targetDisplayName,
        coachIdForProfilePhoto: AppConfig.isClient ? coachId : null,
        onCancel: () => outgoingCancelled = true,
      ),
      transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
    nav.push(outgoingRoute);

    String? notifyCallerName;
    String? notifyCallerImageUrl;
    String? channelName;

    try {
      if (AppConfig.isCoach && callerId != null && callerId.isNotEmpty) {
        final coach =
            await SupabaseCoachesRepository().fetchCoachById(callerId);
        notifyCallerName = coach?.name.trim();
        if (notifyCallerName == null || notifyCallerName.isEmpty) {
          notifyCallerName = 'Coach';
        }
        final url = coach?.profileImageUrl?.trim();
        notifyCallerImageUrl = (url != null && url.isNotEmpty) ? url : null;
      } else {
        notifyCallerName =
            _notifyCallerNameWhenClient(clientName: clientName);
        notifyCallerImageUrl = null;
      }

      if (callerId != null && calleeId.isNotEmpty) {
        channelName = await sendIncomingCallNotification(
          calleeUserId: calleeId,
          callerId: callerId,
          callerName: notifyCallerName,
          callerImageUrl: notifyCallerImageUrl,
        );
      }
    } catch (e, st) {
      debugPrint('Error placing video call: $e\n$st');
    }

    if (!context.mounted) return;

    if (outgoingCancelled || !outgoingRoute.isCurrent) {
      return;
    }

    if (channelName == null || channelName.isEmpty) {
      nav.pop();
      if (!context.mounted) return;
      showErrorBottomSheet(
        context: context,
        message:
            'Could not start the video call. Check your connection and try again.',
      );
      return;
    }

    nav.pushReplacement(
      PageRouteBuilder<void>(
        fullscreenDialog: true,
        opaque: true,
        pageBuilder: (ctx, animation, secondaryAnimation) => VideoCallScreen(
          targetUserId: calleeId,
          targetUserName: targetDisplayName,
          channelName: channelName!,
        ),
        transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
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

  /// Same contrast as [ChatUIKitAppBar] title / readable on neutralColor98 bar.
  static Color _chatAppBarActionIconColor() {
    final c = ChatUIKitTheme.instance.color;
    return c.isDark ? c.neutralColor95 : c.neutralColor1;
  }

  /// Trailing action for Agora Chat UI Kit app bar (video call).
  static ChatUIKitAppBarAction videoCallAppBarAction({
    required String coachId,
    required String coachName,
    required String clientUserId,
    required String clientName,
  }) {
    return ChatUIKitAppBarAction(
      child: Icon(
        Icons.videocam,
        size: 22,
        color: _chatAppBarActionIconColor(),
      ),
      onTap: (ctx) {
        openVideoCall(
          ctx,
          coachId: coachId,
          coachName: coachName,
          clientUserId: clientUserId,
          clientName: clientName,
        );
      },
    );
  }
}