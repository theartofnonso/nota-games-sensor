/// Game phase from `session_state_change` payloads.
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

  bool get isMotionEligible =>
      isRunning && !isPaused && phase == SessionPhase.work;

  bool get isSessionComplete => phase == SessionPhase.complete;

  /// Pre-start — joined but no phase broadcast yet.
  bool get isWaitingToStart => !isSessionComplete && phase == null;

  /// In-session UI (work, rest, pass break, or paused).
  bool get isInSession =>
      !isSessionComplete && phase != null;

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
