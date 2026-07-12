import 'package:gameware/shared_prefs.dart';

/// Stable device/player identity for NOTA sessions (persisted via [SharedPrefs]).
abstract final class PlayerIdentityStore {
  static const defaultPlayerName = 'Player';

  /// Returns a persisted player id for [sessionId] rejoins, or null on first join.
  static Future<String?> loadPlayerIdForSession(String sessionId) async {
    await SharedPrefs().init();
    final savedSessionId = SharedPrefs().notaMotionSessionId;
    if (savedSessionId != sessionId.trim()) return null;

    final existing = SharedPrefs().notaMotionPlayerId;
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }
    return null;
  }

  /// Persists the server-assigned `playerId` from `POST /sessions/:id/join`.
  static Future<void> savePlayerSession({
    required String sessionId,
    required String playerId,
  }) async {
    await SharedPrefs().init();
    await SharedPrefs().setNotaMotionSessionId(sessionId.trim());
    await SharedPrefs().setNotaMotionPlayerId(playerId.trim());
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

  /// UI label — prepends "Player" without duplicating an existing prefix.
  static String displayName(String playerName) {
    final trimmed = playerName.trim();
    if (trimmed.isEmpty) return defaultPlayerName;
    const prefix = 'Player ';
    if (trimmed.startsWith(prefix)) return trimmed;
    return '$prefix$trimmed';
  }
}
