import 'package:shared_preferences/shared_preferences.dart';
import 'package:tracker_app/screens/preferences/settings_screen.dart';

class SharedPrefs {
  static SharedPreferences? _sharedPrefs;

  factory SharedPrefs() => SharedPrefs._internal();

  SharedPrefs._internal();

  Future<void> init() async {
    _sharedPrefs ??= await SharedPreferences.getInstance();
  }

  void clear() {
    remove(key: _weightUnitKey);
    remove(key: routineLogKey);
  }

  void remove({required String key}) {
    _sharedPrefs?.remove(key);
  }

  Future<void> reload() async {
    await _sharedPrefs?.reload();
  }

  /// Weight Unit Type
  final String _weightUnitKey = "weight_unit_type_key";

  String get weightUnit => _sharedPrefs?.getString(_weightUnitKey) ?? WeightUnit.kg.name;

  set weightUnit(String value) {
    _sharedPrefs?.setString(_weightUnitKey, value);
  }

  /// First launch flag
  final String _firstLaunchKey = "first_launch_key";

  bool get firstLaunch => _sharedPrefs?.getBool(_firstLaunchKey) ?? true;

  set firstLaunch(bool value) {
    _sharedPrefs?.setBool(_firstLaunchKey, value);
  }

  /// Cached routine log
  final String routineLogKey = "routine_log_key";

  String get routineLog => _sharedPrefs?.getString(routineLogKey) ?? "";

  set routineLog(String value) {
    _sharedPrefs?.setString(routineLogKey, value);
  }
}
