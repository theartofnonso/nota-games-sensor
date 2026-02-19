import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:trainware/services/analytics/coach_ai_query_service.dart';

void main() {
  group('CoachAiQueryService', () {
    test('returns backend answer', () async {
      final client = MockClient((http.Request request) async {
        return http.Response(
            jsonEncode({'answer': 'Direct backend answer'}), 200);
      });

      final service = CoachAiQueryService(
        httpClient: client,
        authHeadersProvider: () => {'Content-Type': 'application/json'},
      );

      final result = await service.query(
        query: 'hello',
        clientId: '72e0df29-9310-4075-b9be-e76028f9d6eb',
        dateFrom: DateTime.utc(2026, 1, 1),
        dateTo: DateTime.utc(2026, 2, 1),
        exerciseIds: const [],
      );

      expect(result, 'Direct backend answer');
    });

    test('throws when backend returns empty answer', () async {
      final client = MockClient((http.Request request) async {
        return http.Response(jsonEncode({'answer': '   '}), 200);
      });

      final service = CoachAiQueryService(
        httpClient: client,
        authHeadersProvider: () => {'Content-Type': 'application/json'},
      );

      expect(
        () => service.query(
          query: 'hello',
          clientId: '72e0df29-9310-4075-b9be-e76028f9d6eb',
          dateFrom: DateTime.utc(2026, 1, 1),
          dateTo: DateTime.utc(2026, 2, 1),
          exerciseIds: const [],
        ),
        throwsException,
      );
    });
  });
}
