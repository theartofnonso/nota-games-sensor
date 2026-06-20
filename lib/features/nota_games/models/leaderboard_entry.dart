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

  /// Parses `leaderboard_update` items (`total_xp`) and REST leaderboard rows (`totalXp`).
  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    final xp = json['total_xp'] ?? json['totalXp'] ?? json['score'];
    return LeaderboardEntry(
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
      totalXp: (xp as num).toDouble(),
      rank: json['rank'] as int,
    );
  }
}
