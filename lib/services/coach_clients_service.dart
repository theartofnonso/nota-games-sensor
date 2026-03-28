import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_flavor.dart';
import '../dtos/coach_client_dto.dart';
import 'chat_unread_counts_service.dart';

/// Loads and caches coach clients. Used at startup (splash) so the coach
/// client list is ready before the first screen.
///
/// Extends [ChangeNotifier] so [CoachClientsScreen] rebuilds when a load
/// finishes (the service can update after the first frame).
class CoachClientsService extends ChangeNotifier {
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
  ///
  /// Pass [coachAuthUserId] when you already have the signed-in user id (e.g.
  /// from [ClientOverrideController]) so this matches startup auth state even
  /// if [SupabaseClient.auth.currentUser] lags briefly after session restore.
  Future<void> loadClients({String? coachAuthUserId}) async {
    if (!AppConfig.isCoach) return;

    _loadError = null;
    final coachId = (coachAuthUserId != null && coachAuthUserId.isNotEmpty)
        ? coachAuthUserId
        : Supabase.instance.client.auth.currentUser?.id;
    if (coachId == null) {
      _clients = [];
      _loaded = true;
      notifyListeners();
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('coach_clients')
          .select(
            'id, coach_id, client_id, created_at, clients(id, email, name, created_at)',
          )
          .eq('coach_id', coachId)
          .order('created_at', ascending: false);
      final rows = response as List<dynamic>;
      _clients = rows.map((row) {
        final rowMap = row as Map<String, dynamic>;
        final rawClient = rowMap['clients'];
        final clientsMap = rawClient is Map
            ? Map<String, dynamic>.from(rawClient)
            : null;
        return CoachClientDto.fromJson(rowMap, clientsMap);
      }).toList();
      _loaded = true;

      try {
        await ChatUnreadCountsService()
            .updateClients(_clients.map((c) => c.clientId).toList());
      } catch (_) {
        // Don't fail clients load if Agora/unread service fails
      }
    } catch (e, st) {
      debugPrint('[CoachClients] load failed: $e\n$st');
      _loadError = e;
      _clients = [];
      _loaded = true;
    }
    notifyListeners();
  }

  /// Clears cached data (e.g. on logout).
  void reset() {
    _clients = [];
    _loadError = null;
    _loaded = false;
    notifyListeners();
  }
}
