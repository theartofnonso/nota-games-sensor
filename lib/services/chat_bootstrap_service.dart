import 'dart:convert';

import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../urls.dart';
import '../utils/agora_chat_utils.dart';
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

  static Future<String?> _resolveAgoraToken(String agoraUserId) async {
    try {
      final uri = Uri.parse(agoraBaseUrl).resolve(agoraTokenPath);
      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': agoraUserId}),
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
    if (ChatClient.getInstance.currentUserId == agoraUserId) {
      debugPrint('[ChatBootstrap] Already logged in as $agoraUserId');
      agoraLoggedIn.value = true;
      return;
    }

    try {
      final token = await _resolveAgoraToken(agoraUserId);
      if (token == null || token.isEmpty) {
        debugPrint('[ChatBootstrap] No Agora token; skipping login');
        return;
      }

      await ChatClient.getInstance.loginWithToken(agoraUserId, token);
      if (ChatClient.getInstance.currentUserId != agoraUserId) {
        debugPrint('[ChatBootstrap] Login verification failed');
        return;
      }
      debugPrint('[ChatBootstrap] Agora login OK');
      agoraLoggedIn.value = true;

      await setupPushToken();
      debugPrint('[ChatBootstrap] Push token setup OK');
    } catch (e) {
      debugPrint('[ChatBootstrap] Error: $e');
    }
  }
}
