import 'package:flutter/material.dart';

import 'session_runtime_state.dart';
import 'team_color.dart';

/// Returned by `POST /sessions/:id/join`.
class PlayerSession {
  const PlayerSession({
    required this.playerId,
    required this.playerName,
    required this.sessionId,
    this.teamId,
    this.teamColor,
    this.isRejoin = false,
    this.initialGameState,
  });

  final String playerId;
  final String playerName;
  final String sessionId;
  final String? teamId;

  /// Team accent from the controller (`teamColor` on join). Falls back in [pulseColor].
  final Color? teamColor;
  final bool isRejoin;

  /// Current session state when joining mid-session (`gameState` from join response).
  final SessionRuntimeState? initialGameState;

  /// Pulse colour when assigned to a team; null when unassigned.
  Color? get pulseColor {
    final id = teamId?.trim();
    if (id == null || id.isEmpty) return null;
    return teamColor ?? defaultTeamPulseColor;
  }

  factory PlayerSession.fromJson(Map<String, dynamic> json) {
    SessionRuntimeState? initialGameState;
    final rawGameState = json['gameState'];
    if (rawGameState is Map) {
      initialGameState = SessionRuntimeState.fromSessionStateChange(
        Map<String, dynamic>.from(rawGameState),
      );
    }

    return PlayerSession(
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
      sessionId: json['sessionId'] as String,
      teamId: json['teamId'] as String?,
      teamColor: readTeamColorFromJson(json),
      isRejoin: json['isRejoin'] as bool? ?? false,
      initialGameState: initialGameState,
    );
  }
}
