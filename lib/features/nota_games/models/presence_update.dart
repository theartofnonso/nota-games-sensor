/// `presence_update` broadcast payload.
class PresenceUpdate {
  const PresenceUpdate({
    required this.sessionId,
    required this.updatedAt,
    required this.connectedPlayers,
  });

  final String sessionId;
  final int updatedAt;
  final List<ConnectedPlayer> connectedPlayers;

  factory PresenceUpdate.fromJson(Map<String, dynamic> json) {
    return PresenceUpdate(
      sessionId: json['sessionId'] as String,
      updatedAt: (json['updatedAt'] as num).toInt(),
      connectedPlayers: (json['connectedPlayers'] as List<dynamic>? ?? [])
          .map(
            (e) => ConnectedPlayer.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }
}

class ConnectedPlayer {
  const ConnectedPlayer({
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.joinedAt,
  });

  final String playerId;
  final String playerName;
  final String? teamId;
  final int joinedAt;

  factory ConnectedPlayer.fromJson(Map<String, dynamic> json) {
    return ConnectedPlayer(
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
      teamId: json['teamId'] as String?,
      joinedAt: (json['joinedAt'] as num).toInt(),
    );
  }
}
