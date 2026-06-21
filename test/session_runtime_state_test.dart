import 'package:flutter_test/flutter_test.dart';
import 'package:trainware/features/nota_games/models/session_runtime_state.dart';

void main() {
  group('SessionRuntimeState', () {
    test('parses nested session_state_change payload', () {
      final state = SessionRuntimeState.fromSessionStateChange({
        'timestamp': 1700000000000,
        'state': {
          'phase': 'work',
          'isRunning': true,
          'isPaused': false,
          'timeRemaining': 40,
        },
      });

      expect(state.phase, SessionPhase.work);
      expect(state.isRunning, isTrue);
      expect(state.isPaused, isFalse);
      expect(state.isMotionEligible, isTrue);
      expect(state.timeRemaining, 40);
    });

    test('isMotionEligible requires work phase and running, not paused', () {
      const pausedWork = SessionRuntimeState(
        phase: SessionPhase.work,
        isRunning: true,
        isPaused: true,
      );
      expect(pausedWork.isMotionEligible, isFalse);

      const rest = SessionRuntimeState(
        phase: SessionPhase.rest,
        isRunning: true,
      );
      expect(rest.isMotionEligible, isFalse);

      const complete = SessionRuntimeState(phase: SessionPhase.complete);
      expect(complete.isSessionComplete, isTrue);
    });

    test('accepts pass_break wire value', () {
      final state = SessionRuntimeState.fromJson({
        'phase': 'pass_break',
        'isRunning': false,
      });
      expect(state.phase, SessionPhase.passBreak);
    });
  });
}
