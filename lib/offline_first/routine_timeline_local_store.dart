import 'dart:convert';

import '../dtos/routine_timeline_event_dto.dart';
import '../logger.dart';
import '../shared_prefs.dart';

/// Simplified timeline store: single entry in SharedPrefs, replaced per session.
class RoutineTimelineLocalStore {
  final _logger = getLogger(className: 'RoutineTimelineLocalStore');
  final SharedPrefs _prefs = SharedPrefs();

  /// Stored shape: {"logId": "...", "events": [ ... ] }
  Map<String, dynamic>? _loadRaw() {
    try {
      final raw = _prefs.timelineEvents;
      if (raw.isEmpty) return null;
      final savedAtRaw = _prefs.timelineEventsSavedAt;
      final savedAt =
          savedAtRaw.isEmpty ? null : DateTime.tryParse(savedAtRaw);
      if (_isExpired(savedAt)) {
        clearAll();
        return null;
      }
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e, stackTrace) {
      _logger.w('Failed to load timeline events from prefs: $e\n$stackTrace');
      return null;
    }
  }

  void _saveRaw(Map<String, dynamic> data) {
    try {
      _prefs.timelineEvents = jsonEncode(data);
      _prefs.timelineEventsSavedAt = DateTime.now().toIso8601String();
    } catch (e, stackTrace) {
      _logger.w('Failed to save timeline events to prefs: $e\n$stackTrace');
    }
  }

  Map<String, dynamic>? _loadDraftRaw() {
    try {
      final raw = _prefs.timelineEventsDraft;
      if (raw.isEmpty) return null;
      final savedAtRaw = _prefs.timelineEventsDraftSavedAt;
      final savedAt =
          savedAtRaw.isEmpty ? null : DateTime.tryParse(savedAtRaw);
      if (_isExpired(savedAt)) {
        clearDraft();
        return null;
      }
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e, stackTrace) {
      _logger.w('Failed to load draft timeline events from prefs: $e\n$stackTrace');
      return null;
    }
  }

  void _saveDraftRaw(Map<String, dynamic> data) {
    try {
      _prefs.timelineEventsDraft = jsonEncode(data);
      _prefs.timelineEventsDraftSavedAt = DateTime.now().toIso8601String();
    } catch (e, stackTrace) {
      _logger.w('Failed to save draft timeline events to prefs: $e\n$stackTrace');
    }
  }

  Future<List<RoutineTimelineEventDto>> load(String logId) async {
    final raw = _loadRaw();
    if (raw == null) return const [];
    final storedLogId = raw['logId'] as String? ?? '';
    if (storedLogId != logId) return const [];
    final events = (raw['events'] as List<dynamic>? ?? const [])
        .map((e) => RoutineTimelineEventDto.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();
    return events;
  }

  Future<(String?, List<RoutineTimelineEventDto>)> loadLatest() async {
    final raw = _loadRaw();
    if (raw == null) return (null, <RoutineTimelineEventDto>[]);
    final storedLogId = raw['logId'] as String? ?? '';
    final events = (raw['events'] as List<dynamic>? ?? const [])
        .map((e) => RoutineTimelineEventDto.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();
    return (storedLogId.isEmpty ? null : storedLogId, events);
  }

  Future<(String?, List<RoutineTimelineEventDto>)> loadDraft() async {
    final raw = _loadDraftRaw();
    if (raw == null) return (null, <RoutineTimelineEventDto>[]);
    final storedLogId = raw['logId'] as String? ?? '';
    final events = (raw['events'] as List<dynamic>? ?? const [])
        .map((e) => RoutineTimelineEventDto.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();
    return (storedLogId.isEmpty ? null : storedLogId, events);
  }

  Future<void> saveDraft(
      String logId, List<RoutineTimelineEventDto> events) async {
    _saveDraftRaw({
      'logId': logId,
      'events': events.map((e) => e.toJson()).toList(),
    });
  }

  Future<void> clearDraft() async {
    _prefs.timelineEventsDraft = "";
    _prefs.timelineEventsDraftSavedAt = "";
  }

  bool _isExpired(DateTime? savedAt) {
    if (savedAt == null) return false;
    return DateTime.now().difference(savedAt) > const Duration(hours: 24);
  }

  Future<void> clearAll() async {
    _prefs.timelineEvents = "";
    _prefs.timelineEventsSavedAt = "";
    _prefs.timelineEventsDraft = "";
    _prefs.timelineEventsDraftSavedAt = "";
  }

  Future<void> saveAll(
      String logId, List<RoutineTimelineEventDto> events) async {
    _saveRaw({
      'logId': logId,
      'events': events.map((e) => e.toJson()).toList(),
    });
  }

  Future<void> append(String logId, RoutineTimelineEventDto event) async {
    final raw = _loadRaw();
    final storedLogId = raw?['logId'] as String? ?? '';
    final existing = (raw?['events'] as List<dynamic>? ?? const [])
        .map((e) => RoutineTimelineEventDto.fromJson(
            Map<String, dynamic>.from(e as Map)))
        .toList();

    // Different session? replace entirely.
    if (storedLogId.isEmpty || storedLogId != logId) {
      _saveRaw({
        'logId': logId,
        'events': [event.toJson()],
      });
      return;
    }

    existing.add(event);
    _saveRaw({
      'logId': logId,
      'events': existing.map((e) => e.toJson()).toList(),
    });
  }

  Future<void> replaceLogId(String oldLogId, String newLogId) async {
    final raw = _loadRaw();
    if (raw == null) return;
    final storedLogId = raw['logId'] as String? ?? '';
    if (storedLogId != oldLogId) return;
    _saveRaw({
      'logId': newLogId,
      'events': raw['events'] ?? const [],
    });
  }

  Future<void> clear(String logId) async {
    final raw = _loadRaw();
    if (raw == null) return;
    final storedLogId = raw['logId'] as String? ?? '';
    if (storedLogId != logId) return;
    _saveRaw({'logId': '', 'events': []});
  }

  Future<void> rekeySingleEntryIfNeeded(String newLogId) async {
    final raw = _loadRaw();
    if (raw == null) return;
    final storedLogId = raw['logId'] as String? ?? '';
    if (storedLogId == newLogId) return;
    _saveRaw({
      'logId': newLogId,
      'events': raw['events'] ?? const [],
    });
  }
}
