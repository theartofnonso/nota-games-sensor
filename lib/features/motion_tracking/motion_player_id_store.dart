import 'package:trainware/shared_prefs.dart';
import 'package:uuid/uuid.dart';

/// Stable device/player identity for NOTA motion sessions (persisted via [SharedPrefs]).
abstract final class MotionPlayerIdStore {
  static const defaultPlayerName = 'Player';

  static Future<String> loadOrCreate() async {
    await SharedPrefs().init();
    final existing = SharedPrefs().notaMotionPlayerId;
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }
    final id = const Uuid().v4();
    await SharedPrefs().setNotaMotionPlayerId(id);
    return id;
  }

  static Future<String> loadOrCreateName() async {
    await SharedPrefs().init();
    final existing = SharedPrefs().notaMotionPlayerName;
    if (existing != null && existing.trim().isNotEmpty) {
      return existing.trim();
    }
    await SharedPrefs().setNotaMotionPlayerName(defaultPlayerName);
    return defaultPlayerName;
  }
}
