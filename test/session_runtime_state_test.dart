import 'package:flutter_test/flutter_test.dart';
import 'package:trainware/features/nota_games/models/player_session.dart';
import 'package:trainware/features/nota_games/models/session_runtime_state.dart';

void main() {
  group('SessionRuntimeState', () {
    test('parses sensorActive and sessionEnded from session_state_change', () {
      final state = SessionRuntimeState.fromSessionStateChange({
        'timestamp': 1700000000000,
        'state': {
          'sensorActive': true,
          'sessionEnded': false,
          'phase': 'work',
          'isRunning': true,
          'isPaused': false,
          'timeRemaining': 40,
        },
      });

      expect(state.sensorActive, isTrue);
      expect(state.sessionEnded, isFalse);
      expect(state.isMotionEligible, isTrue);
      expect(state.phase, SessionPhase.work);
      expect(state.timeRemaining, 40);
    });

    test('unwraps nested broadcast payload envelope', () {
      final state = SessionRuntimeState.fromSessionStateChange({
        'event': 'session_state_change',
        'payload': {
          'timestamp': 1,
          'state': {
            'sensorActive': true,
            'sessionEnded': false,
            'phase': 'work',
          },
        },
      });

      expect(state.sensorActive, isTrue);
      expect(state.phase, SessionPhase.work);
    });

    test('sessionEnded ends the session; sensorActive gates motion', () {
      const ended = SessionRuntimeState(sessionEnded: true);
      expect(ended.isSessionComplete, isTrue);
      expect(ended.isMotionEligible, isFalse);

      const idle = SessionRuntimeState(
        sensorActive: false,
        phase: SessionPhase.rest,
      );
      expect(idle.isMotionEligible, isFalse);
      expect(idle.isInSession, isTrue);

      const active = SessionRuntimeState(sensorActive: true);
      expect(active.isMotionEligible, isTrue);
    });

    test('accepts pass_break wire value', () {
      final state = SessionRuntimeState.fromJson({
        'phase': 'pass_break',
        'sensorActive': false,
      });
      expect(state.phase, SessionPhase.passBreak);
    });
  });

  group('PlayerSession', () {
    test('parses optional gameState from join response', () {
      final session = PlayerSession.fromJson({
        'sessionId': 'sess-1',
        'playerId': 'player-1',
        'playerName': 'Alex',
        'isRejoin': false,
        'gameState': {
          'timestamp': 1,
          'state': {
            'sensorActive': true,
            'sessionEnded': false,
            'phase': 'work',
          },
        },
      });

      expect(session.initialGameState?.sensorActive, isTrue);
      expect(session.initialGameState?.phase, SessionPhase.work);
    });
  });
}
