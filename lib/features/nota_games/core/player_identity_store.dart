import 'package:trainware/shared_prefs.dart';
import 'package:uuid/uuid.dart';

/// Stable device/player identity for NOTA sessions (persisted via [SharedPrefs]).
abstract final class PlayerIdentityStore {
  static const defaultPlayerName = 'Player';

  static Future<String> loadOrCreatePlayerId() async {
    await SharedPrefs().init();
    final existing = SharedPrefs().notaMotionPlayerId;
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }
    final id = const Uuid().v4();
    await SharedPrefs().setNotaMotionPlayerId(id);
    return id;
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
