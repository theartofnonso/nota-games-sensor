import 'dart:convert';

import 'package:agora_chat_uikit/chat_uikit.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../app_flavor.dart';
import '../urls.dart';
import '../utils/coach_mapping_utils.dart';
import '../utils/notathletes_auth_headers.dart';
import '../utils/agora_chat_utils.dart';
import 'chat_unread_counts_service.dart';
import 'chat_unread_service.dart';
import 'push_token_service.dart';

/// Runs Agora Chat login and push token registration at app startup so that
/// when the user opens the chat screen, the connection is already warm and
/// data is immediately available.
///
/// Call [ensureAgoraAndPushSetup] when the user becomes authenticated (e.g.
/// from [ClientOverrideController] auth state). Safe to call multiple times;
/// no-ops if already logged in as the same user.
///
/// [agoraLoggedIn] is set to true when Agora has successfully logged in (or
/// was already logged in). Use it to run unread refresh etc. after login.
class ChatBootstrapService {
  ChatBootstrapService._();

  /// True once Agora Chat has logged in this session (or was already logged in).
  static final ValueNotifier<bool> agoraLoggedIn = ValueNotifier(false);

  static const int _peerHistoryPageSize = 50;
  static const int _peerHistoryMaxPages = 80;
  static const int _localScanPageSize = 300;
  static const int _localScanMaxPages = 50;

  static Message? _oldestByServerTime(Iterable<Message> messages) {
    Message? o;
    for (final m in messages) {
      if (o == null || m.serverTime < o.serverTime) o = m;
    }
    return o;
  }

  /// Oldest message id stored locally for [peer], or null if the conversation
  /// is empty. Paged scan so we do not miss history beyond the first N rows.
  static Future<String?> _oldestLocalMessageId(String peer) async {
    Message? globalOldest;
    var startId = '';
    for (var p = 0; p < _localScanMaxPages; p++) {
      final batch = await ChatUIKit.instance.loadLocalMessages(
        conversationId: peer,
        type: ConversationType.Chat,
        count: _localScanPageSize,
        startId: startId,
        direction: SearchDirection.Up,
      );
      if (batch.isEmpty) break;
      final pageOldest = _oldestByServerTime(batch);
      if (pageOldest != null) {
        if (globalOldest == null ||
            pageOldest.serverTime < globalOldest.serverTime) {
          globalOldest = pageOldest;
        }
      }
      if (batch.length < _localScanPageSize) break;
      final nextStart = pageOldest?.msgId.trim() ?? '';
      if (nextStart.isEmpty || nextStart == startId) break;
      startId = nextStart;
    }
    return globalOldest?.msgId.trim();
  }

  /// The UI Kit message list only reads the **local** DB. This pulls server
  /// history into that DB:
  /// - **Empty local:** start from latest and page backward.
  /// - **Some local (e.g. partial sync or only live messages):** anchor on the
  ///   **oldest** stored message and fetch **older** pages until the server has
  ///   no more — we no longer bail out just because `count >= 1` locally.
  static Future<void> ensurePeerChatHistoryLoaded(String peerAgoraUserId) async {
    final peer = peerAgoraUserId.trim();
    if (peer.isEmpty) return;
    final sdkMe = ChatClient.getInstance.currentUserId?.trim() ?? '';
    final me = sdkMe.isNotEmpty
        ? sdkMe
        : (ChatUIKit.instance.currentUserId?.trim() ?? '');
    if (me.isEmpty) return;

    try {
      final anyLocal = await ChatUIKit.instance.loadLocalMessages(
        conversationId: peer,
        type: ConversationType.Chat,
        count: 1,
      );
      // Peer user id = conversationId for 1:1. Empty [startMsgId] = latest window;
      // each response's [cursor] is the next [startMsgId] for older messages
      // (see Agora Chat `fetchHistoryMessages` docs).
      var startMsgId = '';
      if (anyLocal.isNotEmpty) {
        startMsgId = (await _oldestLocalMessageId(peer)) ?? '';
      }

      for (var page = 0; page < _peerHistoryMaxPages; page++) {
        try {
          final pageResult = await ChatUIKit.instance.fetchHistoryMessages(
            conversationId: peer,
            type: ConversationType.Chat,
            pageSize: _peerHistoryPageSize,
            startMsgId: startMsgId,
            direction: SearchDirection.Up,
          );

          final batch = pageResult.data;
          if (batch.isEmpty) break;

          final nextCursor = pageResult.cursor?.trim() ?? '';

          // Match Agora's recommended stop conditions: no cursor or short page.
          if (nextCursor.isEmpty || batch.length < _peerHistoryPageSize) {
            break;
          }
          if (nextCursor == startMsgId) break;
          startMsgId = nextCursor;
        } on ChatError catch (e) {
          debugPrint(
            '[ChatBootstrap] fetchHistoryMessages ChatError: '
            '${e.code} ${e.description}',
          );
          break;
        }
      }
      debugPrint('[ChatBootstrap] Server history sync peer $peer');
    } catch (e, st) {
      debugPrint('[ChatBootstrap] ensurePeerChatHistoryLoaded: $e\n$st');
    }
  }

  /// Resets unread notifiers and [agoraLoggedIn]. Call on sign-out (before or
  /// after [logoutAgoraChat]) so badges don’t show the previous user’s counts.
  static void clearLocalChatState() {
    agoraLoggedIn.value = false;
    ChatUnreadService().clear();
    ChatUnreadCountsService().clear();
  }

  /// Clears local chat UI state and logs out of Agora. Does **not** sign out
  /// Supabase — call [SupabaseClient.auth.signOut] after this when needed.
  static Future<void> logoutAgoraChat() async {
    clearLocalChatState();
    try {
      await ChatClient.getInstance.logout(true);
    } catch (_) {}
    try {
      ChatUIKitContext.instance.currentUserId = null;
    } catch (_) {}
  }

  /// After background [logout(false)], the native SDK can be logged out while
  /// UIKit still holds a stale user id — that skips re-login and yields
  /// `ChatError 201 Not login` when opening messages.
  static void _clearStaleChatUIKitIfSdkLoggedOut() {
    final sdk = ChatClient.getInstance.currentUserId?.trim() ?? '';
    final ui = ChatUIKit.instance.currentUserId?.trim() ?? '';
    if (sdk.isEmpty && ui.isNotEmpty) {
      debugPrint(
        '[ChatBootstrap] Clearing stale ChatUIKit user (SDK logged out, ui=$ui)',
      );
      try {
        ChatUIKitContext.instance.currentUserId = null;
      } catch (_) {}
    }
  }

  static bool _sdkAndUiKitLoggedInAs(String agoraUserId) {
    final sdk = ChatClient.getInstance.currentUserId?.trim() ?? '';
    final ui = ChatUIKit.instance.currentUserId?.trim() ?? '';
    return sdk.isNotEmpty &&
        ui.isNotEmpty &&
        sdk == agoraUserId &&
        ui == agoraUserId;
  }

  /// Fetches an Agora Chat token for the given [supabaseUserId] (raw auth user id).
  /// Backend derives the Agora username. Shared by bootstrap and ChatScreen. Returns null on failure.
  static Future<String?> resolveAgoraChatToken(String supabaseUserId) async {
    try {
      final uri = Uri.parse(agoraBaseUrl).resolve(agoraTokenPath);
      final response = await http.post(
        uri,
        headers: notathletesAuthHeaders(),
        body: jsonEncode({'userId': supabaseUserId}),
      );
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data['token'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('[ChatBootstrap] Token fetch error: $e');
      return null;
    }
  }

  /// Logs into Agora Chat and registers push tokens (APNs/FCM) so chat is
  /// ready when the user opens the chat screen. Call when the user is
  /// authenticated (e.g. after Supabase auth is ready).
  ///
  /// [supabaseUserId] – current Supabase auth user id (not Agora username).
  /// No-op if null, or if already logged in as the corresponding Agora user.
  static Future<void> ensureAgoraAndPushSetup(String? supabaseUserId) async {
    if (supabaseUserId == null || supabaseUserId.isEmpty) return;

    final agoraUserId = toAgoraUsername(supabaseUserId);
    _clearStaleChatUIKitIfSdkLoggedOut();

    if (_sdkAndUiKitLoggedInAs(agoraUserId)) {
      debugPrint('[ChatBootstrap] Already logged in as $agoraUserId');
      agoraLoggedIn.value = true;
      return;
    }

    try {
      final token = await resolveAgoraChatToken(supabaseUserId);
      if (token == null || token.isEmpty) {
        debugPrint('[ChatBootstrap] No Agora token; skipping login');
        agoraLoggedIn.value = false;
        return;
      }

      await ChatUIKit.instance.loginWithToken(
        userId: agoraUserId,
        token: token,
      );
      final uiOk = ChatUIKit.instance.currentUserId?.trim() == agoraUserId;
      final sdkOk = ChatClient.getInstance.currentUserId?.trim() == agoraUserId;
      if (!uiOk || !sdkOk) {
        debugPrint(
          '[ChatBootstrap] Login verification failed '
          '(uiOk=$uiOk sdkOk=$sdkOk expected=$agoraUserId)',
        );
        agoraLoggedIn.value = false;
        return;
      }
      debugPrint('[ChatBootstrap] Agora login OK');
      agoraLoggedIn.value = true;

      // Client app: set up unread tracking for coach→client messages so the
      // chat badge updates without needing to open Settings first
      if (AppConfig.isClient) {
        final coachData = await fetchCoachForClient(supabaseUserId);
        final coachId = coachData?['coachId'];
        if (coachId != null && coachId.isNotEmpty) {
          await ChatUnreadService().updateContext(
            userId: supabaseUserId,
            coachId: coachId,
          );
          debugPrint('[ChatBootstrap] Client unread service OK');
        }
      }

      final pushOk = await setupPushToken();
      if (pushOk) {
        debugPrint('[ChatBootstrap] Push token setup OK');
      } else {
        debugPrint(
          '[ChatBootstrap] Push token setup failed (check Agora Console APNs config)',
        );
      }
    } catch (e) {
      debugPrint('[ChatBootstrap] Error: $e');
      agoraLoggedIn.value = false;
    }
  }
}
