class LeaderboardEntry {
  const LeaderboardEntry({
    required this.playerId,
    required this.playerName,
    required this.totalXp,
    required this.rank,
  });

  final String playerId;
  final String playerName;
  final double totalXp;
  final int rank;

  /// Parses `leaderboard_update` broadcast items.
  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
      totalXp: (json['total_xp'] as num).toDouble(),
      rank: json['rank'] as int,
    );
  }
}
