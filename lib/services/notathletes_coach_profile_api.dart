import 'dart:convert';

import 'package:http/http.dart' as http;

import '../dtos/coach_dto.dart';
import '../urls.dart';
import '../utils/notathletes_auth_headers.dart';

/// GET [apiNotathletesBaseUrl]/coach-profiles/[coachId] with optional Bearer token.
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
      return null;
    }
    final decoded = jsonDecode(response.body);
    return _coachDtoFromCoachProfileResponse(decoded, fallbackCoachId: id);
  } catch (_) {
    return null;
  }
}

/// GET [apiNotathletesBaseUrl]/coach-profiles — all coach profiles for discovery / paywall.
///
/// Accepts a top-level JSON array, or `{ "data": [ ... ] }`, or common `{ "items": ... }` shapes.
Future<List<CoachDto>> fetchCoachProfilesListFromNotathletesApi() async {
  try {
    final uri = Uri.parse(apiNotathletesBaseUrl).resolve(coachProfilesPath);
    final response = await http
        .get(uri, headers: notathletesAuthHeaders())
        .timeout(const Duration(seconds: 30));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return [];
    }
    final decoded = jsonDecode(response.body);
    final items = _unwrapCoachProfileList(decoded);
    final out = <CoachDto>[];
    for (final item in items) {
      final dto = _coachDtoFromCoachProfileResponse(
        item,
        fallbackCoachId: '',
      );
      if (dto != null && dto.id.trim().isNotEmpty) {
        out.add(dto);
      }
    }
    out.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    return out;
  } catch (_) {
    return [];
  }
}

List<dynamic> _unwrapCoachProfileList(dynamic decoded) {
  if (decoded is List) return decoded;
  if (decoded is Map) {
    final m = Map<String, dynamic>.from(decoded);
    final data = m['data'];
    if (data is List) return data;
    if (data is Map) {
      final nested = data['items'] ?? data['coach_profiles'] ?? data['profiles'];
      if (nested is List) return nested;
    }
    for (final key in [
      'coach_profiles',
      'coaches',
      'profiles',
      'results',
      'items',
    ]) {
      final v = m[key];
      if (v is List) return v;
    }
  }
  return const [];
}

CoachDto? _coachDtoFromCoachProfileResponse(
  dynamic decoded, {
  required String fallbackCoachId,
}) {
  if (decoded == null) return null;
  dynamic root = decoded;
  if (root is Map && root['data'] != null) {
    final inner = root['data'];
    // List responses unwrap in [_unwrapCoachProfileList]; here expect a single object.
    if (inner is Map) {
      root = inner;
    }
  }
  if (root is! Map) return null;

  final map = Map<String, dynamic>.from(root);
  final rawId = map['id'];
  final idStr = rawId is String ? rawId.trim() : rawId?.toString().trim() ?? '';
  if (idStr.isEmpty && fallbackCoachId.isNotEmpty) {
    map['id'] = fallbackCoachId;
  }

  try {
    return CoachDto.fromJson(map);
  } catch (_) {
    return null;
  }
}
