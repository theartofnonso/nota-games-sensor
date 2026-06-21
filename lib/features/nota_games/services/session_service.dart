import 'dart:convert';

import '../core/api_client.dart';
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
    final savedPlayerId = await PlayerIdentityStore.loadPlayerId();

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
      await PlayerIdentityStore.savePlayerId(session.playerId);
      return session;
    }
    if (response.statusCode == 403) {
      throw const SessionJoinForbiddenException();
    }
    if (response.statusCode == 404) {
      throw const SessionNotFoundException();
    }
    throw SessionServiceException(
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

  /// `POST /sessions/:id/motion`
  ///
  /// Returns `true` when the batch was accepted (HTTP 202). On 502, returns
  /// `false` so the caller can retry without discarding samples.
  Future<bool> uploadMotion(String sessionId, MotionBatch batch) async {
    final response = await _apiClient.post(
      '/sessions/$sessionId/motion',
      body: batch.toJson(),
    );

    if (response.statusCode == 202) {
      return true;
    }
    if (response.statusCode == 502) {
      return false;
    }
    if (response.statusCode == 403) {
      throw const SessionJoinForbiddenException();
    }
    throw SessionServiceException(
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
