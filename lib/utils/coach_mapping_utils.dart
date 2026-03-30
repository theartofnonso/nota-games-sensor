import 'package:supabase_flutter/supabase_flutter.dart';

/// Reads [coach_clients] for `client_id` → returns `coach_id`.
///
/// Coach display data comes from **GET /coach-profiles/:id** ([fetchAssignedCoachProfile]),
/// not from Supabase `coaches`. [coachName] is left empty here.
Future<Map<String, String>?> fetchCoachForClient(String clientId) async {
  try {
    final row = await Supabase.instance.client
        .from('coach_clients')
        .select('coach_id')
        .eq('client_id', clientId)
        .maybeSingle();
    if (row == null) return null;
    final rawId = row['coach_id'];
    final coachId = switch (rawId) {
      null => null,
      final String s when s.trim().isNotEmpty => s.trim(),
      final num n => n.toString(),
      _ => rawId.toString().trim().isEmpty ? null : rawId.toString().trim(),
    };
    if (coachId == null || coachId.isEmpty) return null;

    return {'coachId': coachId, 'coachName': ''};
  } catch (_) {
    return null;
  }
}
