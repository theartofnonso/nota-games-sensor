/// Game phase from `session_state_change` payloads.
enum SessionPhase {
  work,
  rest,
  passBreak,
  complete;

  static SessionPhase? fromWire(String? value) => switch (value) {
        'work' => SessionPhase.work,
        'rest' => SessionPhase.rest,
        'passBreak' => SessionPhase.passBreak,
        'complete' => SessionPhase.complete,
        _ => null,
      };
}

/// Nested `state` object inside [SessionStateChange].
class GameState {
  const GameState({
    this.sensorActive = false,
    this.sessionEnded = false,
    this.phase,
    this.currentStation,
    this.currentRound,
    this.currentPass,
    this.timeRemaining,
    this.isRunning = false,
    this.isPaused = false,
    this.completedIntervals,
    this.totalIntervals,
  });

  final bool sensorActive;
  final bool sessionEnded;
  final SessionPhase? phase;
  final int? currentStation;
  final int? currentRound;
  final int? currentPass;
  final int? timeRemaining;
  final bool isRunning;
  final bool isPaused;
  final int? completedIntervals;
  final int? totalIntervals;

  factory GameState.fromJson(Map<String, dynamic> json) {
    return GameState(
      sensorActive: json['sensorActive'] as bool? ?? false,
      sessionEnded: json['sessionEnded'] as bool? ?? false,
      phase: SessionPhase.fromWire(json['phase'] as String?),
      currentStation: json['currentStation'] as int?,
      currentRound: json['currentRound'] as int?,
      currentPass: json['currentPass'] as int?,
      timeRemaining: json['timeRemaining'] as int?,
      isRunning: json['isRunning'] as bool? ?? false,
      isPaused: json['isPaused'] as bool? ?? false,
      completedIntervals: json['completedIntervals'] as int?,
      totalIntervals: json['totalIntervals'] as int?,
    );
  }
}

/// `session_state_change` broadcast payload — drives motion and UI.
class SessionStateChange {
  const SessionStateChange({
    required this.timestamp,
    required this.state,
  });

  final int timestamp;
  final GameState state;

  static const initial = SessionStateChange(
    timestamp: 0,
    state: GameState(),
  );

  bool get sensorActive => state.sensorActive;
  bool get sessionEnded => state.sessionEnded;
  SessionPhase? get phase => state.phase;

  /// Joined but no game state yet (pre-start).
  bool get isWaitingToStart =>
      !sessionEnded && phase == null && !sensorActive;

  /// In-session UI (work, rest, pass break, paused, or sensor on).
  bool get isInSession => !sessionEnded && !isWaitingToStart;

  factory SessionStateChange.fromBroadcast(Map<String, dynamic> payload) {
    final normalized = _normalizeEnvelope(payload);

    final rawState = normalized['state'];
    if (rawState is Map) {
      return SessionStateChange(
        timestamp: _readTimestamp(normalized) ?? 0,
        state: GameState.fromJson(Map<String, dynamic>.from(rawState)),
      );
    }

    if (normalized.containsKey('sensorActive') ||
        normalized.containsKey('sessionEnded') ||
        normalized.containsKey('phase')) {
      return SessionStateChange(
        timestamp: _readTimestamp(normalized) ?? 0,
        state: GameState.fromJson(normalized),
      );
    }

    return SessionStateChange.initial;
  }

  static Map<String, dynamic> _normalizeEnvelope(Map<String, dynamic> raw) {
    final nestedPayload = raw['payload'];
    if (nestedPayload is Map) {
      return Map<String, dynamic>.from(nestedPayload);
    }

    final gameState = raw['gameState'];
    if (gameState is Map) {
      return _normalizeEnvelope(Map<String, dynamic>.from(gameState));
    }

    return raw;
  }

  static int? _readTimestamp(Map<String, dynamic> json) {
    final value = json['timestamp'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return null;
  }
}
