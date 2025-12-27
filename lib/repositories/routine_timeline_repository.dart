import '../dtos/routine_timeline_event_dto.dart';
import '../offline_first/routine_timeline_local_store.dart';

class RoutineTimelineRepository {
  final RoutineTimelineLocalStore _store;

  RoutineTimelineRepository({RoutineTimelineLocalStore? store})
      : _store = store ?? RoutineTimelineLocalStore();

  Future<List<RoutineTimelineEventDto>> load(String logId) {
    return _store.load(logId);
  }

  Future<void> append(String logId, RoutineTimelineEventDto event) {
    return _store.append(logId, event);
  }

  Future<void> replaceLogId(String oldLogId, String newLogId) {
    return _store.replaceLogId(oldLogId, newLogId);
  }

  Future<void> clear(String logId) {
    return _store.clear(logId);
  }

  Future<void> ensureRekeyForSavedLog(String newLogId,
      {String? previousLogId}) async {
    if (previousLogId != null && previousLogId.isNotEmpty) {
      await replaceLogId(previousLogId, newLogId);
      return;
    }
    await _store.rekeySingleEntryIfNeeded(newLogId);
  }

  Future<(String?, List<RoutineTimelineEventDto>)> loadLatest() {
    return _store.loadLatest();
  }
}
