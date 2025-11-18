import 'dart:async';

import 'package:collection/collection.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';
import 'package:trainware/enums/muscle_group_enums.dart';
import 'package:trainware/extensions/datetime/datetime_extension.dart';
import 'package:trainware/utils/routine_utils.dart';
import 'package:uuid/uuid.dart';

import '../../dtos/appsync/exercise_dto.dart';
import '../../dtos/exercise_log_dto.dart';
import '../../dtos/set_dtos/set_dto.dart';
import '../../dtos/set_dtos/weight_and_reps_dto.dart';
import '../../dtos/set_dtos/reps_dto.dart';
import '../../enums/posthog_analytics_event.dart';
import '../../logger.dart';

class SupabaseRoutineLogRepository {
  final logger = getLogger(className: "SupabaseRoutineLogRepository");
  final SupabaseClient _client = Supabase.instance.client;

  List<RoutineLogDto> _logs = [];

  UnmodifiableListView<RoutineLogDto> get logs => UnmodifiableListView(_logs);

  Map<String, List<ExerciseLogDto>> _exerciseLogsByExerciseId = {};

  UnmodifiableMapView<String, List<ExerciseLogDto>>
      get exerciseLogsByExerciseId =>
          UnmodifiableMapView(_exerciseLogsByExerciseId);

  Map<MuscleGroup, List<ExerciseLogDto>> _exerciseLogsByMuscleGroup = {};

  UnmodifiableMapView<MuscleGroup, List<ExerciseLogDto>>
      get exerciseLogsByMuscleGroup =>
          UnmodifiableMapView(_exerciseLogsByMuscleGroup);

  void _groupExerciseLogsById() {
    _exerciseLogsByExerciseId =
        groupExerciseLogsByExerciseId(routineLogs: _logs);
  }

  void _groupExerciseLogsByMuscleGroup() {
    _exerciseLogsByMuscleGroup =
        groupExerciseLogsByMuscleGroup(routineLogs: _logs);
  }

  /// Load logs from Supabase
  /// Only loads logs within date range: last year to end of current year
  Future<void> loadLogs() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        logger.w('No user logged in');
        return;
      }

      // Date range: this time last year to end of current year
      final now = DateTime.now();
      final startDate = DateTime(now.year - 1, now.month, now.day);
      final endDate = DateTime(now.year, 12, 31, 23, 59, 59);

      final response = await _client
          .from('routine_logs')
          .select()
          .eq('owner', userId)
          .gte('startTime', startDate.toIso8601String())
          .lte('startTime', endDate.toIso8601String())
          .order('createdAt', ascending: false);

      _logs = (response as List<dynamic>)
          .map((item) => _convertMapToRoutineLogDto(item))
          .toList();

      _groupExerciseLogsById();
      _groupExerciseLogsByMuscleGroup();

      logger.i('Loaded ${_logs.length} logs from Supabase');
    } catch (e) {
      logger.e('Error loading routine logs: $e');
      rethrow;
    }
  }

  RoutineLogDto _convertMapToRoutineLogDto(Map<String, dynamic> map) {
    try {
      final data = {
        'id': map['id'],
        'templateId': map['templateId'] ?? '',
        'name': map['name'] ?? '',
        'notes': map['notes'] ?? '',
        'startTime': map['startTime'],
        'endTime': map['endTime'],
        'exercises': map['exercises'] ?? [],
      };

      return RoutineLogDto.fromJson(json: data);
    } catch (e) {
      logger.e('Error converting map to RoutineLogDto: $e');
      rethrow;
    }
  }

  /// Save a new log
  Future<RoutineLogDto> saveLog(RoutineLogDto logDto) async {
    try {
      // Generate ID if empty
      final id = logDto.id.isEmpty ? const Uuid().v4() : logDto.id;
      final logWithId = logDto.copyWith(id: id);

      // Update exercise logs with routine log ID
      final updatedLog = logWithId.copyWith(
        exerciseLogs: logWithId.exerciseLogs.map((exerciseLog) {
          return exerciseLog.copyWith(routineLogId: id);
        }).toList(),
      );

      // Insert into Supabase
      await _client.from('routine_logs').insert(updatedLog.toJson());

      // Analytics
      await Posthog().capture(
        eventName: PostHogAnalyticsEvent.logRoutine.displayName,
      );

      // Add to in-memory list
      _logs = [updatedLog, ..._logs];
      _groupExerciseLogsById();
      _groupExerciseLogsByMuscleGroup();

      logger.i('Saved log: ${updatedLog.id}');

      return updatedLog;
    } catch (e) {
      logger.e('Error saving log: $e');
      rethrow;
    }
  }

  /// Update an existing log
  Future<void> updateLog(RoutineLogDto log) async {
    try {
      // Update in Supabase
      await _client.from('routine_logs').update(log.toJson()).eq('id', log.id);

      // Update in-memory list
      _logs = _logs.map((item) => item.id == log.id ? log : item).toList();
      _groupExerciseLogsById();
      _groupExerciseLogsByMuscleGroup();

      logger.i('Updated log: ${log.id}');
    } catch (e) {
      logger.e('Error updating log: $e');
      rethrow;
    }
  }

  /// Delete a log
  Future<void> deleteLog(RoutineLogDto log) async {
    try {
      // Delete from Supabase
      await _client.from('routine_logs').delete().eq('id', log.id);

      // Remove from in-memory list
      _logs = _logs.where((item) => item.id != log.id).toList();
      _groupExerciseLogsById();
      _groupExerciseLogsByMuscleGroup();

      logger.i('Deleted log: ${log.id}');
    } catch (e) {
      logger.e('Error deleting log: $e');
      rethrow;
    }
  }

  /// Helper: Get exercise logs for a specific exercise
  List<ExerciseLogDto> whereExerciseLogsForExercise({
    required ExerciseDto exercise,
  }) {
    return _exerciseLogsByExerciseId[exercise.id] ?? [];
  }

  /// Helper: Get all workout dates (first 10 chars of ISO string for deduplication)
  List<DateTime> get allWorkoutDates {
    final uniqueDates = <String, DateTime>{};
    for (final log in _logs) {
      final dateKey = log.startTime.toIso8601String().substring(0, 10);
      uniqueDates[dateKey] = log.startTime;
    }
    return uniqueDates.values.toList();
  }

  /// Helper: Get logs for a specific date
  List<RoutineLogDto> whereLogsForDate(DateTime date) {
    return _logs
        .where((log) => log.startTime.isSameDayMonthYear(date))
        .toList();
  }

  /// Helper: Get all exercise logs
  List<ExerciseLogDto> get allExerciseLogs {
    return _logs.expand((log) => log.exerciseLogs).toList();
  }

  /// Helper: Get logs by template
  List<RoutineLogDto> whereLogsForTemplate(String templateId) {
    return _logs.where((log) => log.templateId == templateId).toList();
  }

  /// Helper: Find a log by ID
  RoutineLogDto? whereLogById(String id) {
    return _logs.firstWhereOrNull((log) => log.id == id);
  }

  /// Helper: Get recent logs
  List<RoutineLogDto> get recentLogs {
    final sorted = List<RoutineLogDto>.from(_logs)
      ..sort((a, b) => b.startTime.compareTo(a.startTime));
    return sorted.take(10).toList();
  }

  /// Helper: Calculate personal bests for an exercise
  Map<String, dynamic> calculatePersonalBests(ExerciseDto exercise) {
    final exerciseLogs = whereExerciseLogsForExercise(exercise: exercise);

    if (exerciseLogs.isEmpty) {
      return {
        'maxWeight': null,
        'maxReps': null,
        'maxVolume': null,
        'bestSet': null,
      };
    }

    double maxWeight = 0;
    int maxReps = 0;
    double maxVolume = 0;
    SetDto? bestSet;

    for (final exerciseLog in exerciseLogs) {
      for (final set in exerciseLog.sets) {
        if (set is WeightAndRepsSetDto) {
          if (set.weight > maxWeight) {
            maxWeight = set.weight;
          }
          if (set.reps > maxReps) {
            maxReps = set.reps;
          }
          final volume = set.weight * set.reps;
          if (volume > maxVolume) {
            maxVolume = volume;
            bestSet = set;
          }
        } else if (set is RepsSetDto) {
          if (set.reps > maxReps) {
            maxReps = set.reps;
          }
        }
      }
    }

    return {
      'maxWeight': maxWeight > 0 ? maxWeight : null,
      'maxReps': maxReps > 0 ? maxReps : null,
      'maxVolume': maxVolume > 0 ? maxVolume : null,
      'bestSet': bestSet,
    };
  }

  /// Helper: Calculate workout statistics
  Map<String, dynamic> get workoutStats {
    final totalWorkouts = _logs.length;
    final totalExercises = allExerciseLogs.length;
    final totalVolume = allExerciseLogs.fold<double>(
      0,
      (sum, log) =>
          sum +
          log.sets.fold<double>(
            0,
            (setSum, set) {
              if (set is WeightAndRepsSetDto) {
                return setSum + (set.weight * set.reps);
              }
              return setSum;
            },
          ),
    );

    final avgDuration = _logs.isEmpty
        ? Duration.zero
        : Duration(
            seconds: _logs
                    .map((log) =>
                        log.endTime.difference(log.startTime).inSeconds)
                    .reduce((a, b) => a + b) ~/
                totalWorkouts,
          );

    return {
      'totalWorkouts': totalWorkouts,
      'totalExercises': totalExercises,
      'totalVolume': totalVolume,
      'avgDuration': avgDuration,
    };
  }
}
