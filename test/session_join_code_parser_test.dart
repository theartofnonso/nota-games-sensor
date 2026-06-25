import 'package:flutter_test/flutter_test.dart';
import 'package:gameware/features/nota_games/core/session_join_code_parser.dart';

void main() {
  const sessionId = '550e8400-e29b-41d4-a716-446655440000';

  group('SessionJoinCodeParser', () {
    test('parses plain uuid', () {
      expect(SessionJoinCodeParser.parse(sessionId), sessionId);
    });

    test('parses nota deep link', () {
      expect(
        SessionJoinCodeParser.parse('nota://join/$sessionId'),
        sessionId,
      );
    });

    test('parses https join path', () {
      expect(
        SessionJoinCodeParser.parse(
          'https://api.example.com/sessions/$sessionId/join',
        ),
        sessionId,
      );
    });

    test('parses query param', () {
      expect(
        SessionJoinCodeParser.parse(
          'https://play.example.com/join?session=$sessionId',
        ),
        sessionId,
      );
    });

    test('parses json payload', () {
      expect(
        SessionJoinCodeParser.parse(
          '{"sessionId":"$sessionId"}',
        ),
        sessionId,
      );
    });

    test('finds uuid embedded in text', () {
      expect(
        SessionJoinCodeParser.parse('join:$sessionId:extra'),
        sessionId,
      );
    });

    test('rejects garbage', () {
      expect(SessionJoinCodeParser.parse('hello'), isNull);
    });
  });
}
