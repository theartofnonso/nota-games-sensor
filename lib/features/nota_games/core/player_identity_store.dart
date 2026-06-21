import 'package:trainware/shared_prefs.dart';

/// Stable device/player identity for NOTA sessions (persisted via [SharedPrefs]).
abstract final class PlayerIdentityStore {
  static const defaultPlayerName = 'Player';

  /// Returns a persisted player id, or null on first join (server assigns one).
  static Future<String?> loadPlayerId() async {
    await SharedPrefs().init();
    final existing = SharedPrefs().notaMotionPlayerId;
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }
    return null;
  }

  /// Persists the server-assigned `playerId` from `POST /sessions/:id/join`.
  static Future<void> savePlayerId(String id) async {
    await SharedPrefs().init();
    await SharedPrefs().setNotaMotionPlayerId(id.trim());
  }

  static Future<String?> loadPlayerName() async {
    await SharedPrefs().init();
    final existing = SharedPrefs().notaMotionPlayerName;
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }
    return null;
  }

  static Future<void> savePlayerName(String name) async {
    await SharedPrefs().init();
    await SharedPrefs().setNotaMotionPlayerName(name.trim());
  }

  static Future<String> loadOrCreatePlayerName() async {
    final saved = await loadPlayerName();
    if (saved != null) return saved;
    await savePlayerName(defaultPlayerName);
    return defaultPlayerName;
  }
}
