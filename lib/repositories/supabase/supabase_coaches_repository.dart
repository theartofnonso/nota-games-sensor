import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../dtos/coach_dto.dart';
import '../../logger.dart';
import '../../urls.dart';
import '../../utils/dummy_mode_utils.dart';
import '../../utils/notathletes_auth_headers.dart';

/// Fetches coaches from [public.coaches].
class SupabaseCoachesRepository {
  final _logger = getLogger(className: 'SupabaseCoachesRepository');
  final SupabaseClient _client = Supabase.instance.client;
  static const int _coachProfilesPageSize = 100;

  /// Fetch all coaches from GET /coach-profiles with pagination.
  /// Returns empty list on error. In release mode, excludes demo coach.
  Future<List<CoachDto>> fetchCoaches() async {
    try {
      final coaches = <CoachDto>[];
      var offset = 0;
      var fetchedAnyPage = false;

      while (true) {
        final uri = Uri.parse(apiNotathletesBaseUrl)
            .resolve(coachProfilesPath)
            .replace(queryParameters: <String, String>{
          'limit': '$_coachProfilesPageSize',
          'offset': '$offset',
        });

        final response = await http
            .get(uri, headers: notathletesAuthHeaders())
            .timeout(const Duration(seconds: 15));

        if (response.statusCode != 200) {
          _logger.e(
              'Error fetching coaches: ${response.statusCode} ${response.body}');
          return await _fetchCoachesFromSupabaseFallback();
        }

        final decoded = jsonDecode(response.body);
        final page = _decodeCoachProfilesPage(decoded);
        fetchedAnyPage = true;
        coaches.addAll(page);

        if (page.length < _coachProfilesPageSize) {
          break;
        }
        offset += _coachProfilesPageSize;
      }

      if (fetchedAnyPage && coaches.isEmpty) {
        _logger.w(
            'Coach profiles endpoint returned empty/unknown shape; using Supabase fallback.');
        return await _fetchCoachesFromSupabaseFallback();
      }

      if (kReleaseMode) {
        return coaches
            .where((c) =>
                (c.email?.toLowerCase().trim() ?? '') != coachDemoEmail)
            .toList();
      }

      return coaches;
    } catch (e) {
      _logger.e('Error fetching coaches: $e');
      return await _fetchCoachesFromSupabaseFallback();
    }
  }

  List<CoachDto> _decodeCoachProfilesPage(dynamic decoded) {
    if (decoded is List) {
      return decoded
          .map((item) =>
              _coachDtoFromCoachProfilesJson(Map<String, dynamic>.from(item)))
          .toList();
    }

    if (decoded is Map<String, dynamic>) {
      final candidateKeys = <String>['coaches', 'data', 'items', 'results', 'rows'];
      for (final key in candidateKeys) {
        final rows = decoded[key];
        if (rows is List) {
          return rows
              .map((item) => _coachDtoFromCoachProfilesJson(
                  Map<String, dynamic>.from(item)))
              .toList();
        }
        if (rows is Map<String, dynamic>) {
          final nested = rows['coaches'] ??
              rows['items'] ??
              rows['results'] ??
              rows['rows'];
          if (nested is List) {
            return nested
                .map(
                    (item) => _coachDtoFromCoachProfilesJson(
                        Map<String, dynamic>.from(item)))
                .toList();
          }
        }
      }
    }

    return <CoachDto>[];
  }

  CoachDto _coachDtoFromCoachProfilesJson(Map<String, dynamic> json) {
    // /coach-profiles response keys:
    // - full_name -> CoachDto.name
    // - short_bio -> CoachDto.description
    // - intro_video_url -> CoachDto.profileVideoUrl
    return CoachDto(
      id: (json['id'] as String?) ?? '',
      name: (json['full_name'] as String?) ??
          (json['name'] as String?) ??
          '',
      profileImageUrl: json['profile_photo_url'] as String? ??
          json['profile_image_url'] as String?,
      profileVideoUrl:
          json['intro_video_url'] as String? ?? json['profile_video_url'] as String?,
      description:
          json['short_bio'] as String? ?? json['description'] as String?,
      email: json['email'] as String?,
      yearsExperience: (json['years_experience'] as num?)?.toInt(),
      qualifications: json['qualifications'] as String?,
      specialties: json['specialties'] as String?,
      interestsHobbies: json['interests_hobbies'] as String?,
    );
  }

  Future<List<CoachDto>> _fetchCoachesFromSupabaseFallback() async {
    try {
      final response = await _client
          .from('coaches')
          .select('id, name, profile_image_url, profile_video_url, description, email')
          .order('name', ascending: true);

      var coaches = (response as List<dynamic>)
          .map((item) => CoachDto.fromJson(Map<String, dynamic>.from(item)))
          .toList();

      if (kReleaseMode) {
        coaches = coaches
            .where((c) =>
                (c.email?.toLowerCase().trim() ?? '') != coachDemoEmail)
            .toList();
      }
      return coaches;
    } catch (e) {
      _logger.e('Error fetching coaches fallback: $e');
      return <CoachDto>[];
    }
  }

  /// Single coach row by `coaches.id` (e.g. logged-in coach’s profile for video call notify).
  Future<CoachDto?> fetchCoachById(String coachId) async {
    if (coachId.isEmpty) return null;
    try {
      final response = await _client
          .from('coaches')
          .select(
              'id, name, profile_image_url, profile_video_url, description, email')
          .eq('id', coachId)
          .maybeSingle();
      if (response == null) return null;
      return CoachDto.fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      _logger.e('Error fetching coach $coachId: $e');
      return null;
    }
  }

  /// Assign client to coach via POST /coach-clients API.
  /// Backend uses service role to insert; RLS allows service_role.
  /// Returns true on success (201) or already assigned (409).
  Future<bool> assignClientToCoach({
    required String coachId,
    required String clientId,
  }) async {
    try {
      final uri =
          Uri.parse(apiNotathletesBaseUrl).resolve(coachClientsPath);
      final response = await http.post(
        uri,
        headers: notathletesAuthHeaders(),
        body: jsonEncode({
          'coach_id': coachId,
          'client_id': clientId,
        }),
      ).timeout(const Duration(seconds: 15));

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
