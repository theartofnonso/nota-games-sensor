import 'package:shared_preferences/shared_preferences.dart';

class SharedPrefs {
  static SharedPreferences? _sharedPrefs;

  factory SharedPrefs() => SharedPrefs._internal();

  SharedPrefs._internal();

  Future<void> init() async {
    _sharedPrefs ??= await SharedPreferences.getInstance();
  }

  final String _notaMotionPlayerIdKey = 'nota_motion_player_id';
  final String _notaMotionSessionIdKey = 'nota_motion_session_id';
  final String _notaMotionPlayerNameKey = 'nota_motion_player_name';

  String? get notaMotionPlayerId =>
      _sharedPrefs?.getString(_notaMotionPlayerIdKey);

  String? get notaMotionSessionId =>
      _sharedPrefs?.getString(_notaMotionSessionIdKey);

  Future<void> setNotaMotionPlayerId(String value) async {
    await _sharedPrefs?.setString(_notaMotionPlayerIdKey, value);
  }

  Future<void> setNotaMotionSessionId(String value) async {
    await _sharedPrefs?.setString(_notaMotionSessionIdKey, value);
  }

  String? get notaMotionPlayerName =>
      _sharedPrefs?.getString(_notaMotionPlayerNameKey);

  Future<void> setNotaMotionPlayerName(String value) async {
    await _sharedPrefs?.setString(_notaMotionPlayerNameKey, value);
  }
}
