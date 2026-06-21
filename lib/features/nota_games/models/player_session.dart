/// Returned by `POST /sessions/:id/join`.
class PlayerSession {
  const PlayerSession({
    required this.playerId,
    required this.playerName,
    required this.sessionId,
    this.teamId,
    this.duoId,
    this.isRejoin = false,
  });

  final String playerId;
  final String playerName;
  final String sessionId;
  final String? teamId;
  final String? duoId;
  final bool isRejoin;

  factory PlayerSession.fromJson(Map<String, dynamic> json) {
    return PlayerSession(
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
      sessionId: json['sessionId'] as String,
      teamId: json['teamId'] as String?,
      duoId: json['duoId'] as String?,
      isRejoin: json['isRejoin'] as bool? ?? false,
    );
  }
}
