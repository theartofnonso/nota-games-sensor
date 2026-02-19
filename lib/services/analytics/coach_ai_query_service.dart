import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../logger.dart';
import '../../urls.dart';
import '../../utils/notathletes_auth_headers.dart';

class CoachAiQueryService {
  CoachAiQueryService({
    http.Client? httpClient,
    Map<String, String> Function()? authHeadersProvider,
  })  : _httpClient = httpClient ?? http.Client(),
        _authHeadersProvider = authHeadersProvider ?? notathletesAuthHeaders;

  final http.Client _httpClient;
  final Map<String, String> Function() _authHeadersProvider;
  final _logger = getLogger(className: 'CoachAiQueryService');

  Future<String> query({
    required String query,
    required String clientId,
    required DateTime dateFrom,
    required DateTime dateTo,
    required List<String> exerciseIds,
  }) async {
    final uri = Uri.parse(openAiBaseUrl).resolve(aiQueryPath);
    final requestBody = <String, dynamic>{
      'query': query,
      'client_id': clientId,
      'date_from': _dateOnly(dateFrom),
      'date_to': _dateOnly(dateTo),
      if (exerciseIds.isNotEmpty) 'exercise_ids': exerciseIds,
    };

    _logger.i(
      '[AI Chat] POST $uri query="$query" client_id=$clientId date_from=${requestBody['date_from']} date_to=${requestBody['date_to']}',
    );

    final response = await _httpClient.post(
      uri,
      headers: _authHeadersProvider(),
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      _logger.w(
        '[AI Chat] Non-200 status=${response.statusCode} body=${response.body}',
      );
      throw Exception('AI query failed with status ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>? ?? {};
    final answer = (body['answer'] as String?)?.trim();
    if (answer == null || answer.isEmpty) {
      throw Exception('AI query succeeded but no answer was returned');
    }
    return answer;
  }

  String _dateOnly(DateTime value) {
    final d = value.toUtc();
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
}
