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

  /// Timeline events (single entry; replaced per session)
  final String timelineEventsKey = "timeline_events_key";

  String get timelineEvents =>
      _sharedPrefs?.getString(timelineEventsKey) ?? "";

  set timelineEvents(String value) {
    _sharedPrefs?.setString(timelineEventsKey, value);
  }

  /// Draft timeline events (for in-progress sessions; cleared on save/discard)
  final String timelineEventsDraftKey = "timeline_events_draft_key";
  final String timelineEventsDraftSavedAtKey =
      "timeline_events_draft_saved_at_key";

  String get timelineEventsDraft =>
      _sharedPrefs?.getString(timelineEventsDraftKey) ?? "";

  set timelineEventsDraft(String value) {
    _sharedPrefs?.setString(timelineEventsDraftKey, value);
  }

  String get timelineEventsDraftSavedAt =>
      _sharedPrefs?.getString(timelineEventsDraftSavedAtKey) ?? "";

  set timelineEventsDraftSavedAt(String value) {
    _sharedPrefs?.setString(timelineEventsDraftSavedAtKey, value);
  }

  /// Timestamp for persisted recap
  final String timelineEventsSavedAtKey = "timeline_events_saved_at_key";

  String get timelineEventsSavedAt =>
      _sharedPrefs?.getString(timelineEventsSavedAtKey) ?? "";

  set timelineEventsSavedAt(String value) {
    _sharedPrefs?.setString(timelineEventsSavedAtKey, value);
  }
}
