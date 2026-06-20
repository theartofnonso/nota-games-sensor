/// Session phase driven by `session_state_change` events from the host.
enum SessionStatus {
  waiting,
  active,
  paused,
  passBreak,
  ended;

  static SessionStatus fromWire(String value) => switch (value) {
        'active' => SessionStatus.active,
        'paused' => SessionStatus.paused,
        'pass_break' => SessionStatus.passBreak,
        'ended' => SessionStatus.ended,
        _ => SessionStatus.waiting,
      };

  String get wireName => switch (this) {
        SessionStatus.waiting => 'waiting',
        SessionStatus.active => 'active',
        SessionStatus.paused => 'paused',
        SessionStatus.passBreak => 'pass_break',
        SessionStatus.ended => 'ended',
      };
}
