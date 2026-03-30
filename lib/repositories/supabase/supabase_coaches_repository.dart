import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../dtos/coach_dto.dart';
import '../../logger.dart';
import '../../urls.dart';
import '../../utils/dummy_mode_utils.dart';
import '../../utils/notathletes_auth_headers.dart';

/// Reads coach rows from [public.coaches] with embedded [coach_profiles].
/// Assignments use the Not Athletes API.
class SupabaseCoachesRepository {
  final _logger = getLogger(className: 'SupabaseCoachesRepository');
  final SupabaseClient _client = Supabase.instance.client;

  /// Coach list columns + full profile row (via `coach_profile_id` FK).
  static const String _coachSelectWithProfile = '''
id,
name,
email,
coach_profile_id,
coach_profiles (*)
''';

  /// Active coaches from Supabase (with profiles), ordered by name.
  /// Release builds hide the demo coach.
  Future<List<CoachDto>> fetchCoaches() async {
    try {
      final response = await _client
          .from('coaches')
          .select(_coachSelectWithProfile)
          .eq('active', true)
          .order('name', ascending: true);

      var coaches =
          (response as List<dynamic>)
              .map(
                (item) => _coachDtoFromJoinedRow(
                  Map<String, dynamic>.from(item as Map),
                ),
              )
              .toList();

      if (kReleaseMode) {
        coaches =
            coaches
                .where(
                  (c) =>
                      (c.email?.toLowerCase().trim() ?? '') != coachDemoEmail,
                )
                .toList();
      }
      return coaches;
    } catch (e) {
      _logger.e('Error fetching coaches: $e');
      return <CoachDto>[];
    }
  }

  /// Single coach by `coaches.id`, including embedded `coach_profiles`.
  Future<CoachDto?> fetchCoachById(String coachId) async {
    if (coachId.isEmpty) return null;
    try {
      final response =
          await _client
              .from('coaches')
              .select(_coachSelectWithProfile)
              .eq('id', coachId)
              .maybeSingle();
      if (response == null) return null;
      return _coachDtoFromJoinedRow(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      _logger.e('Error fetching coach $coachId: $e');
      return null;
    }
  }

  /// Maps a `coaches` row plus optional nested `coach_profiles` object to [CoachDto].
  ///
  /// Supports common column names on `coach_profiles` (and legacy API-style names).
  static CoachDto _coachDtoFromJoinedRow(Map<String, dynamic> row) {
    final raw = row['coach_profiles'];
    final Map<String, dynamic>? profile =
        raw is Map ? Map<String, dynamic>.from(raw) : null;

    final coachName = (row['name'] as String?)?.trim() ?? '';
    final profileName = _firstNonEmptyString(profile, const [
      'full_name',
      'display_name',
    ]);

    return CoachDto(
      id: row['id'] as String? ?? '',
      name: profileName ?? coachName,
      profileImageUrl: _firstNonEmptyString(profile, const [
        'profile_image_url',
        'profile_photo_url',
      ]),
      profileVideoUrl: _firstNonEmptyString(profile, const [
        'profile_video_url',
        'intro_video_url',
      ]),
      description: _firstNonEmptyString(profile, const [
        'description',
        'short_bio',
      ]),
      email: row['email'] as String?,
      yearsExperience: _firstInt(profile, const ['years_experience']),
      yearsExperienceText: null,
      qualifications: _firstNonEmptyString(profile, const ['qualifications']),
      specialties: _firstNonEmptyString(profile, const ['specialties']),
      interestsHobbies: _firstNonEmptyString(profile, const [
        'interests_hobbies',
      ]),
    );
  }

  static String? _firstNonEmptyString(
    Map<String, dynamic>? map,
    List<String> keys,
  ) {
    if (map == null) return null;
    for (final k in keys) {
      final v = map[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    return null;
  }

  static int? _firstInt(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return null;
    for (final k in keys) {
      final v = map[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
    }
    return null;
  }

  /// Assign client to coach via POST /coach-clients API.
  /// Backend uses service role to insert; RLS allows service_role.
  /// Returns true on success (201) or already assigned (409).
  Future<bool> assignClientToCoach({
    required String coachId,
    required String clientId,
  }) async {
    try {
      final uri = Uri.parse(apiNotathletesBaseUrl).resolve(coachClientsPath);
      final response = await http
          .post(
            uri,
            headers: notathletesAuthHeaders(),
            body: jsonEncode({'coach_id': coachId, 'client_id': clientId}),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 201) {
        _logger.i('Assigned client $clientId to coach $coachId');
        return true;
      }
      if (response.statusCode == 409) {
        _logger.i('Client already assigned to coach');
        return true;
      }
      _logger.e('Assign coach failed: ${response.statusCode} ${response.body}');
      return false;
    } catch (e) {
      _logger.e('Error assigning client to coach: $e');
      return false;
    }
  }
}
