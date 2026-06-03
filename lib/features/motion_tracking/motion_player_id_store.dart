import 'package:trainware/shared_prefs.dart';
import 'package:uuid/uuid.dart';

/// Stable device/player id for NOTA motion sessions (persisted via [SharedPrefs]).
abstract final class MotionPlayerIdStore {
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
}
