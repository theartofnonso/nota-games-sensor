import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_flavor.dart';
import '../dtos/coach_dto.dart';
import '../utils/assigned_coach_utils.dart';

/// Caches the signed-in **client** user's assigned coach profile, loaded during
/// [AppStartupService] (splash) so subscribe UI can read without waiting.
class AssignedCoachService {
  AssignedCoachService._();
  static final AssignedCoachService instance = AssignedCoachService._();

  CoachDto? _profile;
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  CoachDto? get profile => _profile;

  /// Loads from Supabase ([fetchAssignedCoachProfile]) and updates [profile].
  Future<void> refreshFromRemote() async {
    if (!AppConfig.isClient) {
      _profile = null;
      revision.value++;
      return;
    }
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      _profile = null;
      revision.value++;
      return;
    }
    _profile = await fetchAssignedCoachProfile();
    revision.value++;
  }

  void clear() {
    _profile = null;
    revision.value++;
  }

  /// Fills cache when another screen fetched a profile splash missed (e.g. RLS timing).
  void adoptIfEmpty(CoachDto? fetched) {
    if (_profile != null || fetched == null) return;
    _profile = fetched;
    revision.value++;
  }
}
