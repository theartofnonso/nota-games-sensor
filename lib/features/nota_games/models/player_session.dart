import 'session_runtime_state.dart';

/// Returned by `POST /sessions/:id/join`.
class PlayerSession {
  const PlayerSession({
    required this.playerId,
    required this.playerName,
    required this.sessionId,
    this.teamId,
    this.duoId,
    this.isRejoin = false,
    this.initialGameState,
  });

  final String playerId;
  final String playerName;
  final String sessionId;
  final String? teamId;
  final String? duoId;
  final bool isRejoin;

  /// Current session state when joining mid-session (`gameState` from join response).
  final SessionRuntimeState? initialGameState;

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
      duoId: json['duoId'] as String?,
      isRejoin: json['isRejoin'] as bool? ?? false,
      initialGameState: initialGameState,
    );
  }
}
