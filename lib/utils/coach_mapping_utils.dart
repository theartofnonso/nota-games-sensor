import 'package:supabase_flutter/supabase_flutter.dart';

/// Fetches assigned coach id (and name when RLS allows) for a client.
///
/// Uses [coach_clients] first — avoids relying on a nested `coaches` embed,
/// which can fail under RLS while the assignment row is still readable.
Future<Map<String, String>?> fetchCoachForClient(String clientId) async {
  try {
    final row = await Supabase.instance.client
        .from('coach_clients')
        .select('coach_id')
        .eq('client_id', clientId)
        .maybeSingle();
    if (row == null) return null;
    final coachId = row['coach_id'] as String?;
    if (coachId == null || coachId.isEmpty) return null;

    var coachName = '';
    try {
      final coach = await Supabase.instance.client
          .from('coaches')
          .select('name')
          .eq('id', coachId)
          .maybeSingle();
      coachName = (coach?['name'] as String?)?.trim() ?? '';
    } catch (_) {}

    return {'coachId': coachId, 'coachName': coachName};
  } catch (_) {
    return null;
  }
}
