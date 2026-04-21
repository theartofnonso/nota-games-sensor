import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/services/notathletes_coach_profile_api.dart';

/// Reads [coach_clients] for `client_id` → returns `coach_id`.
///
/// Unlisted clients get `clients` + `coach_clients` via **`POST /unlisted-client-bootstrap`** at startup.
///
/// When [includeCoachName] is true, also resolves coach display name via
/// **GET /coach-profiles/:id** so callers (like chat routing) can show
/// "Coach <Name>" without a separate lookup.
Future<Map<String, String>?> fetchCoachForClient(
  String clientId, {
  bool includeCoachName = true,
}) async {
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

    var coachName = '';
    if (includeCoachName) {
      final profile = await fetchCoachProfileFromNotathletesApi(coachId);
      final resolvedName = profile?.name.trim() ?? '';
      if (resolvedName.isNotEmpty) {
        coachName = resolvedName;
      }
    }

    return {'coachId': coachId, 'coachName': coachName};
  } catch (_) {
    return null;
  }
}
