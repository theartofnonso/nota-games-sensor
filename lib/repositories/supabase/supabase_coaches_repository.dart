import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../dtos/coach_dto.dart';
import '../../logger.dart';
import '../../urls.dart';
import '../../utils/notathletes_auth_headers.dart';

/// Fetches coaches from [public.coaches].
class SupabaseCoachesRepository {
  final _logger = getLogger(className: 'SupabaseCoachesRepository');
  final SupabaseClient _client = Supabase.instance.client;

  /// Fetch all coaches. Returns empty list on error.
  Future<List<CoachDto>> fetchCoaches() async {
    try {
      final response = await _client
          .from('coaches')
          .select('id, name, profile_image_url, description, email')
          .order('name', ascending: true);

      final list = response as List<dynamic>;
      return list
          .map((item) => CoachDto.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (e) {
      _logger.e('Error fetching coaches: $e');
      return [];
    }
  }

  /// Assign client to coach via POST /coach-clients.
  /// Returns true on success (201) or already assigned (409).
  Future<bool> assignClientToCoach({
    required String coachId,
    required String clientId,
  }) async {
    try {
      final uri =
          Uri.parse(apiNotathletesBaseUrl).resolve(coachClientsPath);
      final response = await http
          .post(
            uri,
            headers: notathletesAuthHeaders(),
            body: jsonEncode({
              'coach_id': coachId,
              'client_id': clientId,
            }),
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
