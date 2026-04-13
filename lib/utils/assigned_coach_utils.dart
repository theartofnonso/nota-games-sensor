import 'package:supabase_flutter/supabase_flutter.dart';

import '../dtos/coach_dto.dart';
import '../services/notathletes_coach_profile_api.dart';
import 'coach_mapping_utils.dart';

/// Assigned coach profile for the signed-in client.
///
/// Uses [fetchCoachForClient] (unlisted clients get a fixed coach id; see there), then
/// Not Athletes **GET /coach-profiles/:id** and [CoachDto.fromJson].
Future<CoachDto?> fetchAssignedCoachProfile() async {
  final user = Supabase.instance.client.auth.currentUser;
  if (user == null) return null;
  final map = await fetchCoachForClient(user.id);
  if (map == null) return null;
  final coachId = map['coachId']?.trim();
  if (coachId == null || coachId.isEmpty) return null;
  return fetchCoachProfileFromNotathletesApi(coachId);
}
