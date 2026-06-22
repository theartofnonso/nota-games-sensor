import 'dart:convert';

import '../core/api_client.dart';
import '../core/nota_api_error.dart';
import '../core/player_identity_store.dart';
import '../models/motion_sample.dart';
import '../models/player_session.dart';

/// Join / leave session and upload motion batches.
class SessionService {
  SessionService({NotaApiClient? apiClient})
      : _apiClient = apiClient ?? NotaApiClient();

  final NotaApiClient _apiClient;

  /// `POST /sessions/:id/join` — self-join from the phone with name (+ optional rejoin id).
  Future<PlayerSession> join(
    String sessionId, {
    required String playerName,
  }) async {
    await PlayerIdentityStore.savePlayerName(playerName);
    final savedPlayerId =
        await PlayerIdentityStore.loadPlayerIdForSession(sessionId);

    final body = <String, dynamic>{'playerName': playerName};
    if (savedPlayerId != null) {
      body['playerId'] = savedPlayerId;
    }

    final response = await _apiClient.post(
      '/sessions/$sessionId/join',
      body: body,
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final session = PlayerSession.fromJson(json);
      await PlayerIdentityStore.savePlayerSession(
        sessionId: sessionId,
        playerId: session.playerId,
      );
      return session;
    }
    if (response.statusCode == 400) {
      throw SessionServiceException(
        parseNotaApiErrorMessage(response.body) ??
            'Invalid join request. Check your name and try again.',
      );
    }
    if (response.statusCode == 403) {
      throw const SessionJoinForbiddenException();
    }
    if (response.statusCode == 404) {
      throw const SessionNotFoundException();
    }
    throw SessionServiceException(
      parseNotaApiErrorMessage(response.body) ??
          'Join failed: HTTP ${response.statusCode}',
    );
  }

  /// `DELETE /sessions/:id/leave`
  Future<void> leave(String sessionId, {required String playerId}) async {
    final response = await _apiClient.delete(
      '/sessions/$sessionId/leave',
      body: {'playerId': playerId},
    );

    if (response.statusCode >= 400) {
      throw SessionServiceException(
        'Leave failed: HTTP ${response.statusCode}',
      );
    }
  }

  /// `POST /sessions/:id/motion` — expects HTTP 202 on success.
  Future<void> uploadMotion(String sessionId, MotionBatch batch) async {
    final response = await _apiClient.post(
      '/sessions/$sessionId/motion',
      body: batch.toJson(),
    );

    if (response.statusCode == 202) {
      return;
    }
    if (response.statusCode == 400) {
      throw SessionServiceException(
        parseNotaApiErrorMessage(response.body) ??
            'Invalid motion batch.',
      );
    }
    if (response.statusCode == 403) {
      throw const SessionJoinForbiddenException();
    }
    throw SessionServiceException(
      parseNotaApiErrorMessage(response.body) ??
          'Motion upload failed: HTTP ${response.statusCode}',
    );
  }
}

class SessionServiceException implements Exception {
  const SessionServiceException(this.message);
  final String message;
}

class SessionJoinForbiddenException implements Exception {
  const SessionJoinForbiddenException();
}

class SessionNotFoundException implements Exception {
  const SessionNotFoundException();
}
