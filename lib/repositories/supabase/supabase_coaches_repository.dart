import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../dtos/coach_dto.dart';
import '../../logger.dart';
import '../../utils/dummy_mode_utils.dart';

/// Fetches coaches from [public.coaches].
class SupabaseCoachesRepository {
  final _logger = getLogger(className: 'SupabaseCoachesRepository');
  final SupabaseClient _client = Supabase.instance.client;

  /// Fetch all coaches. Returns empty list on error.
  /// In release mode, excludes the demo coach (coach@ware.health).
  Future<List<CoachDto>> fetchCoaches() async {
    try {
      final response = await _client
          .from('coaches')
          .select('id, name, profile_image_url, description, email')
          .order('name', ascending: true);

      final list = response as List<dynamic>;
      var coaches = list
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
      _logger.e('Error fetching coaches: $e');
      return [];
    }
  }

  /// Assign client to coach via direct Supabase insert.
  /// Uses RLS "Client can assign themselves to a coach" (auth.uid() = client_id).
  /// Returns true on success or already assigned (unique constraint).
  Future<bool> assignClientToCoach({
    required String coachId,
    required String clientId,
  }) async {
    try {
      await _client.from('coach_clients').insert({
        'coach_id': coachId,
        'client_id': clientId,
      });
      _logger.i('Assigned client $clientId to coach $coachId');
      return true;
    } on PostgrestException catch (e) {
      // 23505 = unique_violation (already assigned)
      if (e.code == '23505') {
        _logger.i('Client already assigned to coach');
        return true;
      }
      _logger.e('Error assigning client to coach: $e');
      return false;
    } catch (e) {
      _logger.e('Error assigning client to coach: $e');
      return false;
    }
  }
}
