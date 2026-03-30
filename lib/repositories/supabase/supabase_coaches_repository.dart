import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../dtos/coach_dto.dart';
import '../../logger.dart';
import '../../services/notathletes_coach_profile_api.dart';
import '../../urls.dart';
import '../../utils/dummy_mode_utils.dart';
import '../../utils/notathletes_auth_headers.dart';

/// Coach **list and detail** come from Not Athletes
/// `GET https://api.notathletes.com/coach-profiles` and
/// `GET …/coach-profiles/:id` ([fetchCoachProfilesListFromNotathletesApi],
/// [fetchCoachProfileFromNotathletesApi]). Assignments use `POST /coach-clients`.
class SupabaseCoachesRepository {
  final _logger = getLogger(className: 'SupabaseCoachesRepository');

  /// Public coach profiles from Not Athletes API, ordered by name.
  /// The demo coach ([coachDemoEmail]) is never returned (client acquisition).
  Future<List<CoachDto>> fetchCoaches() async {
    try {
      var coaches = await fetchCoachProfilesListFromNotathletesApi();
      coaches =
          coaches
              .where(
                (c) =>
                    (c.email?.toLowerCase().trim() ?? '') !=
                    coachDemoEmail.toLowerCase(),
              )
              .toList();
      for (final c in coaches) {
        _logMappedCoach(c);
      }
      return coaches;
    } catch (e) {
      _logger.e('Error fetching coaches: $e');
      return <CoachDto>[];
    }
  }

  /// Single coach profile from Not Athletes API.
  Future<CoachDto?> fetchCoachById(String coachId) async {
    if (coachId.isEmpty) return null;
    try {
      final coach = await fetchCoachProfileFromNotathletesApi(coachId);
      if (coach != null) {
        _logMappedCoach(coach);
      }
      return coach;
    } catch (e) {
      _logger.e('Error fetching coach $coachId: $e');
      return null;
    }
  }

  void _logMappedCoach(CoachDto coach) {
    const maxLen = 240;
    String? clip(String? s) {
      if (s == null) return null;
      final t = s.trim();
      if (t.length <= maxLen) return t;
      return '${t.substring(0, maxLen)}…';
    }

    try {
      final payload = <String, dynamic>{
        'id': coach.id,
        'name': coach.name,
        'email': coach.email,
        'profileImageUrl': coach.profileImageUrl,
        'profileVideoUrl': coach.profileVideoUrl,
        'description': clip(coach.description),
        'yearsExperience': coach.yearsExperience,
        'yearsExperienceText': coach.yearsExperienceText,
        'experienceDisplayLine': coach.experienceDisplayLine,
        'qualifications': clip(coach.qualifications),
        'specialties': clip(coach.specialties),
        'interestsHobbies': clip(coach.interestsHobbies),
      };
      _logger.i('Mapped coach (Not Athletes API): ${jsonEncode(payload)}');
    } catch (e, st) {
      _logger.w(
        'Mapped coach log encode failed id=${coach.id} name=${coach.name}: $e\n$st',
      );
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
