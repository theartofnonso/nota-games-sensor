import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../dtos/appsync/exercise_dto.dart';
import '../dtos/appsync/routine_log_dto.dart';
import '../dtos/exercise_log_dto.dart';
import '../dtos/routine_timeline_event_dto.dart';
import '../dtos/set_dtos/set_dto.dart';
import '../dtos/set_dtos/weight_and_reps_dto.dart';
import '../dtos/set_dtos/reps_dto.dart';
import '../dtos/set_dtos/duration_set_dto.dart';
import '../logger.dart';
import '../repositories/exercise_log_repository.dart';
import '../repositories/routine_timeline_repository.dart';
import '../shared_prefs.dart';
import 'package:uuid/uuid.dart';

class ExerciseLogController extends ChangeNotifier {
  late ExerciseLogRepository _exerciseLogRepository;
  late RoutineTimelineRepository _timelineRepository;

  final logger = getLogger(className: "ExerciseLogController");

  String? _sessionLogId;
  bool _sessionStartRecorded = false;
  final List<RoutineTimelineEventDto> _pendingTimelineEvents = [];
  bool _draftHydrated = false;

  ExerciseLogController(
    ExerciseLogRepository exerciseLogRepository, {
    RoutineTimelineRepository? timelineRepository,
  }) {
    _exerciseLogRepository = exerciseLogRepository;
    _timelineRepository = timelineRepository ?? RoutineTimelineRepository();
  }

  UnmodifiableListView<ExerciseLogDto> get exerciseLogs =>
      _exerciseLogRepository.exerciseLogs;

  RoutineLogDto? _initialRoutineLog;
  bool _shouldCacheToSharedPrefs = false;

  String get _activeLogId {
    if (_sessionLogId != null) return _sessionLogId!;
    final id = _initialRoutineLog?.id;
    _sessionLogId = (id != null && id.isNotEmpty) ? id : const Uuid().v4();
    return _sessionLogId!;
  }

  void _recordTimelineEvent({
    required String action,
    required String summary,
    String? exerciseId,
    String? exerciseName,
    int? setIndex,
    bool? checked,
    Map<String, dynamic>? metadata,
  }) {
    final event = RoutineTimelineEventDto(
      logId: _activeLogId,
      action: action,
      timestamp: DateTime.now(),
      summary: summary,
      exerciseId: exerciseId,
      exerciseName: exerciseName,
      setIndex: setIndex,
      checked: checked,
      metadata: metadata,
    );

    // Only persist once the session is saved; buffer in memory for now.
    _pendingTimelineEvents.add(event);
    // Also persist draft so in-progress sessions survive restarts.
    unawaited(
        _timelineRepository.saveDraft(_activeLogId, List.of(_pendingTimelineEvents)));
  }

  void loadRoutineLog(
      {required RoutineLogDto routineLog, bool shouldCache = false}) {
    _initialRoutineLog = routineLog;
    if (_sessionLogId == null && routineLog.id.isNotEmpty) {
      _sessionLogId = routineLog.id;
    }
    if (!_sessionStartRecorded) {
      _recordTimelineEvent(
        action: 'session_start',
        summary: 'Started session',
      );
      _sessionStartRecorded = true;
    }

    // Only enable caching if explicitly requested (for live workout sessions)
    // and if this matches the cached workout (to prevent mixing data)
    if (shouldCache) {
      final cachedLog = SharedPrefs().routineLog;
      if (cachedLog.isNotEmpty) {
        try {
          final cachedJson = jsonDecode(cachedLog);
          final cachedRoutineLog = RoutineLogDto.fromJson(json: cachedJson);
          // Only cache if we're editing the same workout that's cached
          _shouldCacheToSharedPrefs = cachedRoutineLog.id == routineLog.id;
        } catch (e) {
          // If we can't parse cached log, don't cache
          _shouldCacheToSharedPrefs = false;
        }
      } else {
        // No cached workout, enable caching for new workout
        _shouldCacheToSharedPrefs = true;
      }
    } else {
      // Not a live workout session, don't cache
      _shouldCacheToSharedPrefs = false;
    }
    _cache();
    // Hydrate any draft timeline for this session so it survives restarts.
    unawaited(_hydrateDraftTimeline());
  }

  void loadExerciseLogs({required List<ExerciseLogDto> exerciseLogs}) {
    _exerciseLogRepository.loadExerciseLogs(exerciseLogs: exerciseLogs);
    // Only disable caching if we're not in a live workout session
    // (i.e., if _initialRoutineLog is null, meaning we're editing templates/past logs)
    if (_initialRoutineLog == null) {
      _shouldCacheToSharedPrefs = false;
    } else {
      // If we're in a live workout session, cache the updated exercise logs
      _cache();
    }
    // Don't clear _initialRoutineLog here - it's needed for caching during live workouts
    logger.i("load exercise logs");
  }

  ExerciseLogDto? whereExerciseLog({required String exerciseId}) {
    return _exerciseLogRepository.whereExerciseLog(exerciseId: exerciseId);
  }

  void addExerciseLog(
      {required ExerciseDto exercise, required List<SetDto> pastSets}) {
    _exerciseLogRepository.addExerciseLog(
        exercise: exercise, pastSets: pastSets);
    _cache();
    _recordTimelineEvent(
        action: 'add_exercise',
        summary: 'Added ${exercise.name}',
        exerciseId: exercise.id,
        exerciseName: exercise.name);
    logger.i("load exercise log: $exercise");
    notifyListeners();
  }

  void reOrderExerciseLogs({required List<ExerciseLogDto> reOrderedList}) {
    _exerciseLogRepository.reOrderExerciseLogs(reOrderedList: reOrderedList);
    _cache();
    notifyListeners();
  }

  void removeExerciseLog({required String logId}) {
    final removed = _exerciseLogRepository.exerciseLogs
        .firstWhereOrNull((e) => e.id == logId || e.exercise.id == logId);
    _exerciseLogRepository.removeExerciseLog(logId: logId);
    _cache();
    if (removed != null) {
      _recordTimelineEvent(
          action: 'remove_exercise',
          summary: 'Removed ${removed.exercise.name}',
          exerciseId: removed.exercise.id,
          exerciseName: removed.exercise.name);
    }
    notifyListeners();
  }

  void replaceExerciseLog(
      {required String oldExerciseId,
      required ExerciseDto newExercise,
      required List<SetDto> pastSets}) {
    _exerciseLogRepository.replaceExercise(
        oldExerciseId: oldExerciseId,
        newExercise: newExercise,
        pastSets: pastSets);
    _cache();
    notifyListeners();
  }

  void updateExerciseLogNotes(
      {required String exerciseLogId, required String value}) {
    _exerciseLogRepository.updateExerciseLogNotes(
        exerciseLogId: exerciseLogId, value: value);
    _cache();
    notifyListeners();
  }

  void superSetExerciseLogs(
      {required String firstExerciseLogId,
      required String secondExerciseLogId,
      required String superSetId}) {
    _exerciseLogRepository.addSuperSets(
        firstExerciseLogId: firstExerciseLogId,
        secondExerciseLogId: secondExerciseLogId,
        superSetId: superSetId);
    _cache();
    notifyListeners();
  }

  void removeSuperSet({required String superSetId}) {
    _exerciseLogRepository.removeSuperSet(superSetId: superSetId);
    _cache();
    notifyListeners();
  }

  void addSet({required String exerciseLogId, required List<SetDto> pastSets}) {
    _exerciseLogRepository.addSet(
        exerciseLogId: exerciseLogId, pastSets: pastSets);
    _cache();
    final exerciseLog = _exerciseLogRepository.exerciseLogs
        .firstWhereOrNull((e) => e.id == exerciseLogId);
    if (exerciseLog != null) {
      _recordTimelineEvent(
        action: 'add_set',
        summary:
            'Added set ${exerciseLog.sets.length} to ${exerciseLog.exercise.name}',
        exerciseId: exerciseLog.exercise.id,
        exerciseName: exerciseLog.exercise.name,
        setIndex: exerciseLog.sets.length - 1,
      );
    }
    notifyListeners();
  }

  void overwriteSets(
      {required String exerciseLogId, required List<SetDto> newSets}) {
    _exerciseLogRepository.overwriteSets(
        exerciseLogId: exerciseLogId, sets: newSets);
    _cache();
    final exerciseLog = _exerciseLogRepository.exerciseLogs
        .firstWhereOrNull((e) => e.id == exerciseLogId);
    if (exerciseLog != null) {
      _recordTimelineEvent(
        action: 'overwrite_sets',
        summary:
            'Replaced sets for ${exerciseLog.exercise.name} (total ${newSets.length})',
        exerciseId: exerciseLog.exercise.id,
        exerciseName: exerciseLog.exercise.name,
      );
    }
    notifyListeners();
  }

  void removeSetForExerciseLog(
      {required String exerciseLogId, required int index}) {
    _exerciseLogRepository.removeSet(
        exerciseLogId: exerciseLogId, index: index);
    _cache();
    notifyListeners();
  }

  void updateWeight(
      {required String exerciseLogId,
      required int index,
      required SetDto setDto}) {
    _exerciseLogRepository.updateWeight(
        exerciseLogId: exerciseLogId, index: index, setDto: setDto);
    _cache();
    notifyListeners();
  }

  void updateReps(
      {required String exerciseLogId,
      required int index,
      required SetDto setDto}) {
    _exerciseLogRepository.updateReps(
        exerciseLogId: exerciseLogId, index: index, setDto: setDto);
    _cache();
    notifyListeners();
  }

  void updateDuration(
      {required String exerciseLogId,
      required int index,
      required SetDto setDto,
      required bool notify}) {
    _exerciseLogRepository.updateDuration(
        exerciseLogId: exerciseLogId, index: index, setDto: setDto);
    _cache();
    if (notify) {
      notifyListeners();
    }
  }

  void updateSetCheck(
      {required String exerciseLogId,
      required int index,
      required SetDto setDto}) {
    final exerciseLog = _exerciseLogRepository.exerciseLogs
        .firstWhereOrNull((e) => e.id == exerciseLogId);
    _exerciseLogRepository.updateSetCheck(
        exerciseLogId: exerciseLogId, index: index, setDto: setDto);
    _cache();
    if (exerciseLog != null) {
      final action = setDto.checked ? 'check_set' : 'uncheck_set';
      final setNumber = index + 1;
      _recordTimelineEvent(
        action: action,
        summary:
            '${setDto.checked ? 'Checked' : 'Unchecked'} set $setNumber for ${exerciseLog.exercise.name}',
        exerciseId: exerciseLog.exercise.id,
        exerciseName: exerciseLog.exercise.name,
        setIndex: index,
        checked: setDto.checked,
        metadata: _setMetrics(setDto),
      );
    }
    notifyListeners();
  }

  List<SetDto> completedSets() {
    return _exerciseLogRepository.completedSets();
  }

  List<ExerciseLogDto> completedExerciseLog() {
    return _exerciseLogRepository.completedExerciseLogs();
  }

  Future<List<RoutineTimelineEventDto>> timelineForLog(String logId) {
    if (logId.isEmpty) return Future.value(const []);
    return _timelineRepository.load(logId);
  }

  /// Clear only in-memory state. Does NOT touch the cached routineLog in SharedPrefs.
  void clearLocal() {
    _exerciseLogRepository.clear();
    _initialRoutineLog = null;
    _shouldCacheToSharedPrefs = false;
    _sessionLogId = null;
    _sessionStartRecorded = false;
    _pendingTimelineEvents.clear();
  }

  /// Persist pending timeline events for a successfully saved session.
  Future<void> persistTimelineForSavedLog(String logId) async {
    if (_pendingTimelineEvents.isEmpty) return;
    await _timelineRepository.saveAll(logId, List.of(_pendingTimelineEvents));
    await _timelineRepository.clearDraft();
    _pendingTimelineEvents.clear();
  }

  /// Clear both in-memory state and the cached pending routine log.
  /// Optionally record a session end event and persist timeline when the session is saved.
  Future<void> onClear({
    bool recordSessionEnd = false,
    bool persistTimeline = false,
    String? savedLogId,
  }) async {
    if (recordSessionEnd) {
      _recordTimelineEvent(
        action: 'session_end',
        summary: 'Ended session',
      );
    }
    if (persistTimeline && savedLogId != null) {
      await persistTimelineForSavedLog(savedLogId);
    } else {
      _pendingTimelineEvents.clear();
      await _timelineRepository.clearDraft();
    }
    clearLocal();
    SharedPrefs().remove(key: SharedPrefs().routineLogKey);
  }

  void _cache() {
    // Only cache if we're editing the active unsaved workout
    if (!_shouldCacheToSharedPrefs) return;

    final routineLog = _initialRoutineLog?.copyWith(
        exerciseLogs: exerciseLogs, endTime: DateTime.now());
    if (routineLog != null) {
      SharedPrefs().routineLog = jsonEncode(routineLog,
          toEncodable: (Object? value) => value is RoutineLogDto
              ? value.toJson()
              : throw UnsupportedError('Cannot convert to JSON: $value'));
    }
  }

  Map<String, dynamic> _setMetrics(SetDto setDto) {
    if (setDto is WeightAndRepsSetDto) {
      return {
        'weight': setDto.weight,
        'reps': setDto.reps,
      };
    }
    if (setDto is RepsSetDto) {
      return {
        'reps': setDto.reps,
      };
    }
    if (setDto is DurationSetDto) {
      return {
        'durationMs': setDto.duration.inMilliseconds,
      };
    }
    return {};
  }

  Future<void> _hydrateDraftTimeline() async {
    if (_draftHydrated) return;
    _draftHydrated = true;
    final draft = await _timelineRepository.loadDraft();
    final draftLogId = draft.$1;
    final draftEvents = draft.$2;
    if (draftLogId == null || draftLogId.isEmpty) {
      return;
    }
    // Ensure the draft belongs to the active session; if no session id yet, adopt it.
    if (_sessionLogId == null) {
      _sessionLogId = draftLogId;
    }
    if (_activeLogId != draftLogId) {
      // Different session; discard stale draft.
      await _timelineRepository.clearDraft();
      return;
    }
    _pendingTimelineEvents
      ..clear()
      ..addAll(draftEvents);
  }
}
