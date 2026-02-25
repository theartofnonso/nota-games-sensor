import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_flavor.dart';
import '../dtos/coach_client_dto.dart';
import 'chat_unread_counts_service.dart';

/// Loads and caches coach clients. Used at startup (splash) so the coach
/// client list is ready before the first screen.
class CoachClientsService {
  CoachClientsService._();
  static final CoachClientsService instance = CoachClientsService._();

  List<CoachClientDto> _clients = [];
  Object? _loadError;

  List<CoachClientDto> get clients => List.unmodifiable(_clients);
  Object? get loadError => _loadError;
  bool get hasLoaded => _loadError != null || _clients.isNotEmpty || _loaded;
  bool _loaded = false;

  /// Loads coach clients from Supabase. Called during app startup for coaches
  /// and on pull-to-refresh in CoachClientsScreen.
  Future<void> loadClients() async {
    if (!AppConfig.isCoach) return;

    _loadError = null;
    final coachId = Supabase.instance.client.auth.currentUser?.id;
    if (coachId == null) {
      _clients = [];
      _loaded = true;
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('coach_clients')
          .select(
              'id, coach_id, client_id, created_at, clients!inner(id, email, name, created_at), coaches (id, email, name)')
          .eq('coach_id', coachId)
          .order('created_at', ascending: false);
      final rows = response as List<dynamic>;
      _clients = rows
          .map((row) {
            final clientsMap = row['clients'] as Map<String, dynamic>?;
            if (clientsMap == null) return null;
            final coachesMap = row['coaches'] as Map<String, dynamic>?;
            return CoachClientDto.fromJson(
                row as Map<String, dynamic>, clientsMap, coachesMap);
          })
          .whereType<CoachClientDto>()
          .toList();
      _loaded = true;

      try {
        await ChatUnreadCountsService()
            .updateClients(_clients.map((c) => c.clientId).toList());
      } catch (_) {
        // Don't fail clients load if Agora/unread service fails
      }
    } catch (e) {
      _loadError = e;
      _clients = [];
    }
  }

  /// Clears cached data (e.g. on logout).
  void reset() {
    _clients = [];
    _loadError = null;
    _loaded = false;
  }
}
