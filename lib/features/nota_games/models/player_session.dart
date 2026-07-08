import 'package:flutter/material.dart';

import 'session_state_change.dart';
import 'team.dart';

/// Returned by `POST /sessions/:id/join`.
class PlayerSession {
  const PlayerSession({
    required this.sessionId,
    required this.playerId,
    required this.playerName,
    this.team,
    this.isRejoin = false,
    this.gameState,
  });

  final String sessionId;
  final String playerId;
  final String playerName;
  final Team? team;
  final bool isRejoin;

  /// Current session state when joining mid-session (`gameState` from join response).
  final SessionStateChange? gameState;

  Color? get pulseColor {
    final team = this.team;
    if (team == null) return null;
    return team.flutterColor ?? defaultTeamPulseColor;
  }

  factory PlayerSession.fromJson(Map<String, dynamic> json) {
    SessionStateChange? gameState;
    final rawGameState = json['gameState'];
    if (rawGameState is Map) {
      gameState = SessionStateChange.fromBroadcast(
        Map<String, dynamic>.from(rawGameState),
      );
    }

    return PlayerSession(
      sessionId: json['sessionId'] as String,
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
      team: Team.fromJson(json['team']),
      isRejoin: json['isRejoin'] as bool? ?? false,
      gameState: gameState,
    );
  }
}
