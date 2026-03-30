import 'dart:convert';

import 'package:http/http.dart' as http;

import '../dtos/coach_dto.dart';
import '../logger.dart';
import '../urls.dart';
import '../utils/notathletes_auth_headers.dart';

final _log = getLogger(className: 'NotathletesCoachProfileApi');

/// GET [apiNotathletesBaseUrl]/coach-profiles/[coachId] with Supabase Bearer token.
///
/// Response body is parsed with [CoachDto.fromJson] (optional `{ "data": { ... } }` unwrap).
Future<CoachDto?> fetchCoachProfileFromNotathletesApi(String coachId) async {
  final id = coachId.trim();
  if (id.isEmpty) return null;
  try {
    final uri =
        Uri.parse(apiNotathletesBaseUrl).resolve('$coachProfilesPath/$id');
    final response = await http
        .get(uri, headers: notathletesAuthHeaders())
        .timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _log.w(
        'GET coach-profiles failed: ${response.statusCode} ${response.body}',
      );
      return null;
    }
    final decoded = jsonDecode(response.body);
    return _coachDtoFromCoachProfileResponse(decoded, fallbackCoachId: id);
  } catch (e, st) {
    _log.w('GET coach-profiles error', error: e, stackTrace: st);
    return null;
  }
}

CoachDto? _coachDtoFromCoachProfileResponse(
  dynamic decoded, {
  required String fallbackCoachId,
}) {
  if (decoded == null) return null;
  dynamic root = decoded;
  if (root is Map && root['data'] != null) {
    root = root['data'];
  }
  if (root is! Map) return null;

  final map = Map<String, dynamic>.from(root);
  final rawId = map['id'];
  final idStr = rawId is String ? rawId.trim() : rawId?.toString().trim() ?? '';
  if (idStr.isEmpty) {
    map['id'] = fallbackCoachId;
  }

  try {
    return CoachDto.fromJson(map);
  } catch (e, st) {
    _log.w('coach-profiles JSON did not match CoachDto', error: e, stackTrace: st);
    return null;
  }
}
