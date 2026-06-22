/// Game phase from `session_state_change` payloads (UI / scoreboard).
enum SessionPhase {
  work,
  rest,
  passBreak,
  complete;

  static SessionPhase? fromWire(String? value) => switch (value) {
        'work' => SessionPhase.work,
        'rest' => SessionPhase.rest,
        'passBreak' || 'pass_break' => SessionPhase.passBreak,
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
    final rawState = payload['state'];
    if (rawState is! Map) return SessionRuntimeState.initial;

    return SessionRuntimeState.fromJson(
      Map<String, dynamic>.from(rawState),
      timestamp: payload['timestamp'] as int?,
    );
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
      timestamp: timestamp ?? json['timestamp'] as int?,
    );
  }
}
