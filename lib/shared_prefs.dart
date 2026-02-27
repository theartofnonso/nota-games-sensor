import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trainware/screens/preferences/settings_screen.dart';

class SharedPrefs {
  static SharedPreferences? _sharedPrefs;
  static final ValueNotifier<int> _routineLogRevision = ValueNotifier(0);

  factory SharedPrefs() => SharedPrefs._internal();

  SharedPrefs._internal();

  Future<void> init() async {
    _sharedPrefs ??= await SharedPreferences.getInstance();
  }

  void clear() {
    remove(key: _weightUnitKey);
    remove(key: routineLogKey);
    _sharedPrefs?.remove(_healthAccessGrantedKey);
    _sharedPrefs?.remove(_healthLastSyncDateKey);
  }

  void remove({required String key}) {
    _sharedPrefs?.remove(key);
    if (key == routineLogKey) {
      _bumpRoutineLogRevision();
    }
  }

  Future<void> reload() async {
    await _sharedPrefs?.reload();
  }

  /// Weight Unit Type
  final String _weightUnitKey = "weight_unit_type_key";

  String get weightUnit =>
      _sharedPrefs?.getString(_weightUnitKey) ?? WeightUnit.kg.name;

  set weightUnit(String value) {
    _sharedPrefs?.setString(_weightUnitKey, value);
  }

  /// First launch flag
  final String _firstLaunchKey = "first_launch_key";

  bool get firstLaunch => _sharedPrefs?.getBool(_firstLaunchKey) ?? true;

  set firstLaunch(bool value) {
    _sharedPrefs?.setBool(_firstLaunchKey, value);
  }

  /// Coach selection completed (mock flow). The mock flow doesn't write to
  /// coach_clients, so fetchCoachForClient stays null. This flag records that
  /// the user completed the flow so we allow main app access until real backend
  /// assignment exists. Cleared on logout.
  final String _coachSelectionCompleteKey = "coach_selection_complete_key";

  bool get coachSelectionComplete =>
      _sharedPrefs?.getBool(_coachSelectionCompleteKey) ?? false;

  set coachSelectionComplete(bool value) {
    _sharedPrefs?.setBool(_coachSelectionCompleteKey, value);
  }

  /// Cached routine log
  final String routineLogKey = "routine_log_key";

  String get routineLog => _sharedPrefs?.getString(routineLogKey) ?? "";

  set routineLog(String value) {
    _sharedPrefs?.setString(routineLogKey, value);
    _bumpRoutineLogRevision();
  }

  ValueListenable<int> get routineLogRevision => _routineLogRevision;

  /// Health metrics (Apple Health) access granted by user
  final String _healthAccessGrantedKey = "health_access_granted_key";
  bool get healthAccessGranted =>
      _sharedPrefs?.getBool(_healthAccessGrantedKey) ?? false;
  set healthAccessGranted(bool value) {
    _sharedPrefs?.setBool(_healthAccessGrantedKey, value);
  }

  /// Last date we synced health data to backend (for backfill)
  final String _healthLastSyncDateKey = "health_last_sync_date_key";
  DateTime? get healthLastSyncDate {
    final s = _sharedPrefs?.getString(_healthLastSyncDateKey);
    if (s == null) return null;
    return DateTime.tryParse(s);
  }
  set healthLastSyncDate(DateTime? value) {
    if (value == null) {
      _sharedPrefs?.remove(_healthLastSyncDateKey);
    } else {
      _sharedPrefs?.setString(_healthLastSyncDateKey, value.toIso8601String());
    }
  }

  void _bumpRoutineLogRevision() {
    _routineLogRevision.value++;
  }

}
