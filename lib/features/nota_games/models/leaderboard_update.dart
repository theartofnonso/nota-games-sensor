/// `leaderboard_update` broadcast payload.
class LeaderboardUpdate {
  const LeaderboardUpdate({
    required this.sessionId,
    required this.updatedAt,
    required this.teams,
    required this.leaderboard,
  });

  final String sessionId;
  final int updatedAt;
  final List<TeamScore> teams;
  final List<LeaderboardEntry> leaderboard;

  factory LeaderboardUpdate.fromJson(Map<String, dynamic> json) {
    return LeaderboardUpdate(
      sessionId: json['sessionId'] as String,
      updatedAt: (json['updatedAt'] as num).toInt(),
      teams: (json['teams'] as List<dynamic>? ?? [])
          .map((e) => TeamScore.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
      leaderboard: (json['leaderboard'] as List<dynamic>? ?? [])
          .map(
            (e) => LeaderboardEntry.fromJson(
              Map<String, dynamic>.from(e as Map),
            ),
          )
          .toList(),
    );
  }

  LeaderboardEntry? entryForPlayer(String playerId) {
    for (final entry in leaderboard) {
      if (entry.playerId == playerId) return entry;
    }
    return null;
  }

  TeamScore? teamScoreFor(String? teamId) {
    if (teamId == null) return null;
    for (final team in teams) {
      if (team.teamId == teamId) return team;
    }
    return null;
  }
}

class TeamScore {
  const TeamScore({
    required this.teamId,
    required this.name,
    required this.color,
    required this.totalXp,
  });

  final String teamId;
  final String name;
  final String color;
  final double totalXp;

  factory TeamScore.fromJson(Map<String, dynamic> json) {
    return TeamScore(
      teamId: json['teamId'] as String,
      name: json['name'] as String,
      color: json['color'] as String,
      totalXp: (json['totalXp'] as num).toDouble(),
    );
  }
}

class LeaderboardEntry {
  const LeaderboardEntry({
    required this.playerId,
    required this.playerName,
    required this.teamId,
    required this.totalXp,
    required this.rank,
  });

  final String playerId;
  final String playerName;
  final String? teamId;
  final double totalXp;
  final int rank;

  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return LeaderboardEntry(
      playerId: json['playerId'] as String,
      playerName: json['playerName'] as String,
      teamId: json['teamId'] as String?,
      totalXp: (json['total_xp'] as num).toDouble(),
      rank: (json['rank'] as num).toInt(),
    );
  }
}
