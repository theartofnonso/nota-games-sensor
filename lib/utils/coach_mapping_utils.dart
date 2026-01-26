import 'package:supabase_flutter/supabase_flutter.dart';

/// Fetches both coach ID and name for a client in a single query.
/// Returns a map with 'coachId' and 'coachName' keys, or null if not found.
Future<Map<String, String>?> fetchCoachForClient(String clientId) async {
  try {
    final response = await Supabase.instance.client
        .from('coach_clients')
        .select('coach_id, coaches (id, name)')
        .eq('client_id', clientId)
        .maybeSingle();
    if (response == null) return null;
    final coachId = response['coach_id'] as String?;
    final coachesMap = response['coaches'] as Map<String, dynamic>?;
    final coachName = coachesMap?['name'] as String?;
    if (coachId == null) return null;
    return {
      'coachId': coachId,
      'coachName': coachName ?? '',
    };
  } catch (_) {
    return null;
  }
}
