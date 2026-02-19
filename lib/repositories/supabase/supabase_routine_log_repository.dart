import 'dart:async';
import 'dart:collection';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';
import 'package:trainware/dtos/appsync/exercise_dto.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';
import 'package:trainware/dtos/set_dtos/duration_set_dto.dart';
import 'package:trainware/dtos/set_dtos/reps_dto.dart';
import 'package:trainware/dtos/set_dtos/set_dto.dart';
import 'package:trainware/dtos/set_dtos/weight_and_reps_dto.dart';
import 'package:trainware/enums/exercise_type_enums.dart';

import '../../logger.dart';

class SupabaseRoutineLogRepository {
  final logger = getLogger(className: "SupabaseRoutineLogRepository");
  final SupabaseClient _client = Supabase.instance.client;

  List<RoutineLogDto> _logs = [];

  UnmodifiableListView<RoutineLogDto> get logs => UnmodifiableListView(_logs);

  /// Returns the owner (user id) of a routine log by id, or null if not found.
  /// Used by coach app to load the correct client when opening a log from a notification.
  Future<String?> getOwnerIdForLog(String logId) async {
    try {
      final sessionRes = await _client
          .from('workout_sessions')
          .select('user_id')
          .eq('id', logId)
          .maybeSingle();
      if (sessionRes != null) {
        return sessionRes['user_id'] as String?;
      }
      return null;
    } catch (e) {
      logger.e('Error fetching owner for log $logId: $e');
      return null;
    }
  }

  /// Load logs from Supabase (read-only; writes go through offline layer).
  /// Only loads logs within date range: last year to end of current year.
  Future<void> loadLogs({String? userIdOverride}) async {
    try {
      final userId = userIdOverride ?? _client.auth.currentUser?.id;
      if (userId == null) {
        logger.w('No user logged in');
        return;
      }

      // Date range: this time last year to end of current year
      final now = DateTime.now();
      final startDate = DateTime(now.year - 1, now.month, now.day);
      final endDate = DateTime(now.year, 12, 31, 23, 59, 59);

      final relationalResponse = await _client
          .from('workout_sessions')
          .select(
              'id,user_id,template_id,name,notes,coach_note,start_time,end_time,created_at,updated_at,session_exercises(id,session_id,exercise_id,template_exercise_id,order_index,super_set_group,notes,exercises!session_exercises_exercise_id_fkey(id,name,type),session_sets(id,session_exercise_id,reps,weight,duration_seconds,is_completed,order_index))')
          .eq('user_id', userId)
          .gte('start_time', startDate.toIso8601String())
          .lte('start_time', endDate.toIso8601String())
          .order('created_at', ascending: false);

      final relationalLogs = (relationalResponse as List<dynamic>)
          .map((item) => _convertRelationalMapToRoutineLogDto(
              Map<String, dynamic>.from(item as Map)))
          .toList();
      _logs = relationalLogs;

      logger.i('Loaded ${_logs.length} logs from Supabase');
    } catch (e) {
      logger.e('Error loading routine logs: $e');
      rethrow;
    }
  }

  RoutineLogDto _convertRelationalMapToRoutineLogDto(Map<String, dynamic> map) {
    final sessionId = map['id'] as String? ?? '';
    final sessionExerciseRows = (map['session_exercises'] as List<dynamic>? ??
            const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList()
      ..sort((a, b) {
        final ai = (a['order_index'] as num?)?.toInt() ?? 0;
        final bi = (b['order_index'] as num?)?.toInt() ?? 0;
        return ai.compareTo(bi);
      });

    final exerciseLogs = sessionExerciseRows
        .map((row) => _convertSessionExerciseRow(
              sessionId: sessionId,
              sessionStartTime: DateTime.parse(map['start_time'] as String),
              row: row,
            ))
        .toList();

    return RoutineLogDto(
      id: sessionId,
      templateId: (map['template_id'] as String?) ?? '',
      name: map['name'] as String? ?? '',
      exerciseLogs: exerciseLogs,
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: DateTime.parse(map['end_time'] as String),
      coachNote: map['coach_note'] as String?,
    );
  }

  ExerciseLogDto _convertSessionExerciseRow({
    required String sessionId,
    required DateTime sessionStartTime,
    required Map<String, dynamic> row,
  }) {
    final exerciseMap = Map<String, dynamic>.from(
      (row['exercises'] as Map?) ?? const {},
    );
    final setRows = (row['session_sets'] as List<dynamic>? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList()
      ..sort((a, b) {
        final ai = (a['order_index'] as num?)?.toInt() ?? 0;
        final bi = (b['order_index'] as num?)?.toInt() ?? 0;
        return ai.compareTo(bi);
      });
    final exerciseType = _resolveExerciseType(
      rawType: exerciseMap['type'] as String?,
      setRows: setRows,
    );
    final exercise = ExerciseDto(
      id: exerciseMap['id'] as String? ?? (row['exercise_id'] as String? ?? ''),
      name: exerciseMap['name'] as String? ?? '',
      type: exerciseType,
      isSystem: true,
    );
    final sets = setRows
        .map((setRow) => _buildSessionSet(setRow: setRow, type: exercise.type))
        .toList();

    return ExerciseLogDto(
      id: exercise.id,
      routineLogId: sessionId,
      superSetId: row['super_set_group'] as String? ?? '',
      exercise: exercise,
      notes: row['notes'] as String? ?? '',
      sets: sets,
      alternatives: const [],
      createdAt: sessionStartTime,
    );
  }

  ExerciseType _resolveExerciseType({
    required String? rawType,
    required List<Map<String, dynamic>> setRows,
  }) {
    final parsed = ExerciseType.fromString(rawType ?? 'NO');
    if (parsed != ExerciseType.none) return parsed;
    if (setRows.any((s) => s['duration_seconds'] != null)) {
      return ExerciseType.duration;
    }
    if (setRows.any((s) => s['weight'] != null)) {
      return ExerciseType.weights;
    }
    if (setRows.any((s) => s['reps'] != null)) {
      return ExerciseType.bodyWeight;
    }
    return ExerciseType.weights;
  }

  SetDto _buildSessionSet({
    required Map<String, dynamic> setRow,
    required ExerciseType type,
  }) {
    final reps = (setRow['reps'] as num?)?.toInt() ?? 0;
    final weight = (setRow['weight'] as num?)?.toDouble() ?? 0;
    final durationSeconds = (setRow['duration_seconds'] as num?)?.toInt() ?? 0;
    final checked = (setRow['is_completed'] as bool?) ?? true;
    final now = DateTime.now();

    return switch (type) {
      ExerciseType.weights => WeightAndRepsSetDto(
          weight: weight,
          reps: reps,
          checked: checked,
          dateTime: now,
        ),
      ExerciseType.bodyWeight => RepsSetDto(
          reps: reps,
          checked: checked,
          dateTime: now,
        ),
      ExerciseType.duration => DurationSetDto(
          duration: Duration(seconds: durationSeconds),
          checked: checked,
          dateTime: now,
        ),
      ExerciseType.none => WeightAndRepsSetDto(
          weight: weight,
          reps: reps,
          checked: checked,
          dateTime: now,
        ),
    };
  }

  /// Updates only the coach_note for a log (used by coaches). Does not touch
  /// exercises, times, or other fields. Throws if no row was updated (e.g. RLS).
  Future<void> updateCoachNote({
    required String logId,
    required String? note,
  }) async {
    final res = await _client
        .from('workout_sessions')
        .update({
          'coach_note': note?.trim().isEmpty ?? true ? null : note!.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', logId)
        .select('id');

    final list = res as List<dynamic>;
    if (list.isEmpty) {
      throw Exception(
        'updateCoachNote: no row updated for logId=$logId (check RLS)',
      );
    }
  }
}
