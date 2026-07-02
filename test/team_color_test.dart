import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gameware/colors.dart';
import 'package:gameware/features/nota_games/models/player_session.dart';
import 'package:gameware/features/nota_games/models/team_color.dart';

void main() {
  group('parseTeamColor', () {
    test('parses hex with hash', () {
      expect(parseTeamColor('#ef4444'), const Color(0xFFEF4444));
    });

    test('parses hex without hash', () {
      expect(parseTeamColor('ef4444'), const Color(0xFFEF4444));
    });
  });

  group('PlayerSession pulseColor', () {
    test('uses default when team assigned without teamColor', () {
      const session = PlayerSession(
        playerId: 'p1',
        playerName: 'Maya',
        sessionId: 's1',
        teamId: 'team-uuid',
      );

      expect(session.pulseColor, defaultTeamPulseColor);
    });

    test('uses controller teamColor when provided', () {
      final session = PlayerSession.fromJson({
        'sessionId': 's1',
        'playerId': 'p1',
        'playerName': 'Maya',
        'teamId': 'team-uuid',
        'teamColor': '#ef4444',
      });

      expect(session.teamColor, const Color(0xFFEF4444));
      expect(session.pulseColor, const Color(0xFFEF4444));
    });

    test('returns null when no team assigned', () {
      const session = PlayerSession(
        playerId: 'p1',
        playerName: 'Maya',
        sessionId: 's1',
      );

      expect(session.pulseColor, isNull);
    });
  });
}
