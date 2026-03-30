import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trainware/enums/weight_unit.dart';

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
    _sharedPrefs?.remove(_profileSetupCompleteKey);
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

  /// Set before client [signOut] from log out / delete account so [MyApp] can
  /// show welcome + Discover coaches again. Consumed in auth listener (see [takeClientPreAuthLandingPending]).
  final String _clientPreAuthLandingPendingKey =
      'client_pre_auth_landing_pending_key';

  void markClientPreAuthLandingPending() {
    _sharedPrefs?.setBool(_clientPreAuthLandingPendingKey, true);
  }

  /// If a client explicitly signed out (or deleted account), returns true once and clears the flag.
  bool takeClientPreAuthLandingPending() {
    final v = _sharedPrefs?.getBool(_clientPreAuthLandingPendingKey) ?? false;
    if (!v) return false;
    _sharedPrefs?.setBool(_clientPreAuthLandingPendingKey, false);
    return true;
  }

  /// Profile setup completed (client has profile in DB). Used to bypass
  /// ProfileCompletionGate on subsequent launches when offline. Cleared on logout.
  final String _profileSetupCompleteKey = "profile_setup_complete_key";

  bool get profileSetupComplete =>
      _sharedPrefs?.getBool(_profileSetupCompleteKey) ?? false;

  set profileSetupComplete(bool value) {
    _sharedPrefs?.setBool(_profileSetupCompleteKey, value);
  }

  /// Cached routine log
  final String routineLogKey = "routine_log_key";

  String get routineLog => _sharedPrefs?.getString(routineLogKey) ?? "";

  set routineLog(String value) {
    _sharedPrefs?.setString(routineLogKey, value);
    _bumpRoutineLogRevision();
  }

  ValueListenable<int> get routineLogRevision => _routineLogRevision;

  void _bumpRoutineLogRevision() {
    _routineLogRevision.value++;
  }

}
