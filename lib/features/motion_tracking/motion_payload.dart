/// Serializable motion sample for real-time backend / dashboard subscribers.
class MotionPayload {
  const MotionPayload({
    required this.playerId,
    required this.timestamp,
    required this.acceleration,
    required this.session,
  });

  final String playerId;
  final DateTime timestamp;
  final MotionAccelerationPayload acceleration;
  final MotionSessionPayload session;

  Map<String, dynamic> toJson() => {
        'playerId': playerId,
        'timestamp': timestamp.toUtc().toIso8601String(),
        'acceleration': acceleration.toJson(),
        'session': session.toJson(),
      };
}

class MotionAccelerationPayload {
  const MotionAccelerationPayload({
    required this.x,
    required this.y,
    required this.z,
    required this.magnitude,
    required this.smoothedMagnitude,
  });

  final double x;
  final double y;
  final double z;
  final double magnitude;
  final double smoothedMagnitude;

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'z': z,
        'magnitude': magnitude,
        'smoothedMagnitude': smoothedMagnitude,
      };
}

class MotionSessionPayload {
  const MotionSessionPayload({
    required this.score,
    required this.isTracking,
  });

  final double score;
  final bool isTracking;

  Map<String, dynamic> toJson() => {
        'score': score,
        'isTracking': isTracking,
      };
}
