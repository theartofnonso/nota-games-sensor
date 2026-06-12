/// Raw linear acceleration sample — matches [PlayerMotionBatch] schema items.
class PlayerMotionSample {
  const PlayerMotionSample({
    required this.timestamp,
    required this.x,
    required this.y,
    required this.z,
  });

  final int timestamp;
  final double x;
  final double y;
  final double z;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp,
        'x': x,
        'y': y,
        'z': z,
      };
}

/// Batched raw accelerometer data for backend publish (scoring is server-side).
class PlayerMotionBatch {
  const PlayerMotionBatch({
    required this.playerId,
    required this.playerName,
    required this.batchStartedAt,
    required this.batchEndedAt,
    required this.sampleRateHz,
    required this.samples,
  });

  final String playerId;
  final String playerName;
  final int batchStartedAt;
  final int batchEndedAt;
  final double sampleRateHz;
  final List<PlayerMotionSample> samples;

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'playerName': playerName,
        'batchStartedAt': batchStartedAt,
        'batchEndedAt': batchEndedAt,
        'sampleRateHz': sampleRateHz,
        'samples': samples.map((s) => s.toJson()).toList(),
      };
}
