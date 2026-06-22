/// Game phase from `session_state_change` payloads (UI / scoreboard).
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

/// Parsed from `session_state_change` — drives motion and UI routing.
class SessionRuntimeState {
  const SessionRuntimeState({
    this.sensorActive = false,
    this.sessionEnded = false,
    this.phase,
    this.isRunning = false,
    this.isPaused = false,
    this.currentStation,
    this.currentRound,
    this.currentPass,
    this.timeRemaining,
    this.completedIntervals,
    this.totalIntervals,
    this.timestamp,
  });

  /// `true` = send motion batches; `false` = stop sending.
  final bool sensorActive;

  /// `true` = call `/leave` and show results.
  final bool sessionEnded;

  final SessionPhase? phase;
  final bool isRunning;
  final bool isPaused;
  final int? currentStation;
  final int? currentRound;
  final int? currentPass;
  final int? timeRemaining;
  final int? completedIntervals;
  final int? totalIntervals;
  final int? timestamp;

  static const initial = SessionRuntimeState();

  bool get isMotionEligible => sensorActive;

  bool get isSessionComplete => sessionEnded;

  /// Joined but no game state yet (pre-start).
  bool get isWaitingToStart =>
      !sessionEnded && phase == null && !sensorActive;

  /// In-session UI (work, rest, pass break, paused, or sensor on).
  bool get isInSession => !sessionEnded && !isWaitingToStart;

  factory SessionRuntimeState.fromSessionStateChange(
    Map<String, dynamic> payload,
  ) {
    final normalized = _normalizeEnvelope(payload);

    final rawState = normalized['state'];
    if (rawState is Map) {
      return SessionRuntimeState.fromJson(
        Map<String, dynamic>.from(rawState),
        timestamp: _readTimestamp(normalized),
      );
    }

    // Flat payload — state fields at the top level.
    if (normalized.containsKey('sensorActive') ||
        normalized.containsKey('sessionEnded') ||
        normalized.containsKey('phase')) {
      return SessionRuntimeState.fromJson(
        normalized,
        timestamp: _readTimestamp(normalized),
      );
    }

    return SessionRuntimeState.initial;
  }

  /// Unwraps Supabase/JS broadcast envelopes and join `gameState` wrappers.
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

  factory SessionRuntimeState.fromJson(
    Map<String, dynamic> json, {
    int? timestamp,
  }) {
    return SessionRuntimeState(
      sensorActive: json['sensorActive'] as bool? ?? false,
      sessionEnded: json['sessionEnded'] as bool? ?? false,
      phase: SessionPhase.fromWire(json['phase'] as String?),
      isRunning: json['isRunning'] as bool? ?? false,
      isPaused: json['isPaused'] as bool? ?? false,
      currentStation: json['currentStation'] as int?,
      currentRound: json['currentRound'] as int?,
      currentPass: json['currentPass'] as int?,
      timeRemaining: json['timeRemaining'] as int?,
      completedIntervals: json['completedIntervals'] as int?,
      totalIntervals: json['totalIntervals'] as int?,
      timestamp: timestamp ?? _readTimestamp(json),
    );
  }
}
