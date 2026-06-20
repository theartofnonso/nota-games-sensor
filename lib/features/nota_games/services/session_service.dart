import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/player_identity_store.dart';
import '../models/motion_sample.dart';
import '../models/player_session.dart';

/// Join / leave session and upload motion batches.
class SessionService {
  SessionService({NotaApiClient? apiClient})
      : _apiClient = apiClient ?? NotaApiClient();

  final NotaApiClient _apiClient;

  /// `POST /sessions/:id/join` — self-join from the phone with device id + name.
  Future<PlayerSession> join(
    String sessionId, {
    required String playerName,
  }) async {
    await PlayerIdentityStore.savePlayerName(playerName);
    final playerId = await PlayerIdentityStore.loadOrCreatePlayerId();

    try {
      final response = await _apiClient.post(
        '/sessions/$sessionId/join',
        body: {
          'playerId': playerId,
          'playerName': playerName,
        },
      );

      if (response.statusCode == 401) {
        throw const SessionUnauthorizedException();
      }
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return PlayerSession.fromJson(json);
      }
      if (response.statusCode == 403) {
        throw const SessionJoinForbiddenException();
      }
      throw SessionServiceException(
        'Join failed: HTTP ${response.statusCode}',
      );
    } on NotaApiStubException {
      final session = PlayerSession(
        playerId: playerId,
        playerName: playerName,
        sessionId: sessionId,
      );
      if (kDebugMode) {
        debugPrint('NOTA stub join session=$sessionId player=$playerId');
      }
      return session;
    }
  }

  /// `DELETE /sessions/:id/leave`
  Future<void> leave(String sessionId) async {
    try {
      final response = await _apiClient.delete('/sessions/$sessionId/leave');

      if (response.statusCode == 401) {
        throw const SessionUnauthorizedException();
      }
      if (response.statusCode >= 400) {
        throw SessionServiceException(
          'Leave failed: HTTP ${response.statusCode}',
        );
      }
    } on NotaApiStubException {
      if (kDebugMode) {
        debugPrint('NOTA stub leave session=$sessionId');
      }
    }
  }

  /// `POST /sessions/:id/motion`
  ///
  /// Returns `true` when the batch was accepted (HTTP 202). On 502, returns
  /// `false` so the caller can retry without discarding samples.
  Future<bool> uploadMotion(String sessionId, MotionBatch batch) async {
    try {
      final response = await _apiClient.post(
        '/sessions/$sessionId/motion',
        body: batch.toJson(),
      );

      if (response.statusCode == 401) {
        throw const SessionUnauthorizedException();
      }
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
    } on NotaApiStubException {
      if (kDebugMode) {
        debugPrint(
          'NOTA stub motion session=$sessionId '
          'samples=${batch.samples.length} '
          'payload=${jsonEncode(batch.toJson())}',
        );
      }
      return true;
    }
  }
}

class SessionServiceException implements Exception {
  const SessionServiceException(this.message);
  final String message;
}

class SessionJoinForbiddenException implements Exception {
  const SessionJoinForbiddenException();
}
