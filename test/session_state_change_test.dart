import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameware/features/nota_games/models/leaderboard_update.dart';
import 'package:gameware/features/nota_games/models/player_session.dart';
import 'package:gameware/features/nota_games/models/session_state_change.dart';
import 'package:gameware/features/nota_games/models/team.dart';

void main() {
  group('SessionStateChange', () {
    test('parses sensorActive and sessionEnded from session_state_change', () {
      final change = SessionStateChange.fromBroadcast({
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

      expect(change.sensorActive, isTrue);
      expect(change.sessionEnded, isFalse);
      expect(change.phase, SessionPhase.work);
      expect(change.state.timeRemaining, 40);
    });

    test('unwraps nested broadcast payload envelope', () {
      final change = SessionStateChange.fromBroadcast({
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

      expect(change.sensorActive, isTrue);
      expect(change.phase, SessionPhase.work);
    });

    test('sessionEnded ends the session; sensorActive gates motion', () {
      const ended = SessionStateChange(
        timestamp: 1,
        state: GameState(sessionEnded: true),
      );
      expect(ended.sessionEnded, isTrue);
      expect(ended.sensorActive, isFalse);

      const idle = SessionStateChange(
        timestamp: 1,
        state: GameState(sensorActive: false, phase: SessionPhase.rest),
      );
      expect(idle.sensorActive, isFalse);
      expect(idle.isInSession, isTrue);

      const active = SessionStateChange(
        timestamp: 1,
        state: GameState(sensorActive: true),
      );
      expect(active.sensorActive, isTrue);
    });

    test('accepts passBreak wire value', () {
      const change = SessionStateChange(
        timestamp: 1,
        state: GameState(phase: SessionPhase.passBreak, sensorActive: false),
      );
      expect(change.phase, SessionPhase.passBreak);
    });
  });

  group('PlayerSession', () {
    test('parses nested team object and gameState from join response', () {
      final session = PlayerSession.fromJson({
        'sessionId': 'sess-1',
        'playerId': 'player-1',
        'playerName': 'Alex',
        'isRejoin': false,
        'team': {
          'id': 'team-red',
          'name': 'Red',
          'color': '#EF4444',
        },
        'gameState': {
          'timestamp': 1,
          'state': {
            'sensorActive': true,
            'sessionEnded': false,
            'phase': 'work',
          },
        },
      });

      expect(session.team?.id, 'team-red');
      expect(session.team?.name, 'Red');
      expect(session.team?.color, '#EF4444');
      expect(session.pulseColor, const Color(0xFFEF4444));
      expect(session.gameState?.sensorActive, isTrue);
      expect(session.gameState?.phase, SessionPhase.work);
    });

    test('team null when session has no teams configured', () {
      final session = PlayerSession.fromJson({
        'sessionId': 'sess-1',
        'playerId': 'player-1',
        'playerName': 'Alex',
        'team': null,
      });

      expect(session.team, isNull);
      expect(session.pulseColor, isNull);
    });
  });

  group('LeaderboardUpdate', () {
    test('parses leaderboard_update payload', () {
      final update = LeaderboardUpdate.fromJson({
        'sessionId': 'sess-1',
        'updatedAt': 1700000000000,
        'teams': [
          {
            'teamId': 'team-red',
            'name': 'Red',
            'color': '#EF4444',
            'totalXp': 1000,
          },
        ],
        'leaderboard': [
          {
            'playerId': 'player-1',
            'playerName': 'Alex',
            'teamId': 'team-red',
            'total_xp': 342.5,
            'rank': 1,
          },
        ],
      });

      expect(update.entryForPlayer('player-1')?.rank, 1);
      expect(update.entryForPlayer('player-1')?.totalXp, 342.5);
      expect(update.teamScoreFor('team-red')?.totalXp, 1000);
    });
  });

  group('Team', () {
    test('parseTeamColor handles hex with hash', () {
      expect(parseTeamColor('#ef4444'), const Color(0xFFEF4444));
    });
  });
}
