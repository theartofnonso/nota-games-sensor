class ConnectedPlayer {
  const ConnectedPlayer({
    required this.playerId,
    required this.playerName,
    this.teamId,
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
      joinedAt: json['joinedAt'] as int,
    );
  }
}
