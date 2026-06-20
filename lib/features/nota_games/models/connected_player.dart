class ConnectedPlayer {
  const ConnectedPlayer({
    required this.playerId,
    required this.playerName,
    this.teamId,
    this.duoId,
    required this.joinedAt,
  });

  final String playerId;
  final String playerName;
  final String? teamId;
  final String? duoId;
  final int joinedAt;

  factory ConnectedPlayer.fromJson(Map<String, dynamic> json) {
    return ConnectedPlayer(
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
      teamId: json['teamId'] as String?,
      duoId: json['duoId'] as String?,
      joinedAt: json['joinedAt'] as int,
    );
  }
}
