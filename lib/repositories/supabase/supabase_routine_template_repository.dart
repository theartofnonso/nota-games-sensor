import 'dart:async';
import 'dart:collection';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';
import 'package:trainware/dtos/set_dtos/duration_set_dto.dart';
import 'package:trainware/dtos/set_dtos/reps_dto.dart';
import 'package:trainware/dtos/set_dtos/set_dto.dart';
import 'package:trainware/dtos/set_dtos/weight_and_reps_dto.dart';
import 'package:trainware/dtos/appsync/routine_template_dto.dart';
import 'package:trainware/dtos/appsync/exercise_dto.dart';
import 'package:trainware/enums/exercise_type_enums.dart';

import '../../logger.dart';

class SupabaseRoutineTemplateRepository {
  final logger = getLogger(className: "SupabaseRoutineTemplateRepository");
  final SupabaseClient _client = Supabase.instance.client;

  List<RoutineTemplateDto> _templates = [];

  UnmodifiableListView<RoutineTemplateDto> get templates =>
      UnmodifiableListView(_templates);

  /// Load templates from Supabase (read-only; writes go through offline layer).
  Future<void> loadTemplates({
    String? ownerIdOverride,
    String? clientIdOverride,
    bool requireOwnerAndClient = false,
  }) async {
    try {
      final authUserId = _client.auth.currentUser?.id;
      final ownerId = ownerIdOverride ?? authUserId;
      final clientId = clientIdOverride ?? authUserId;
      if (ownerId == null || clientId == null) {
        logger.w('No user logged in');
        return;
      }

      final query = _client.from('routine_templates').select(
            'id,planId,name,notes,clientId,createdAt,updatedAt,template_exercises(id,template_id,exercise_id,order_index,super_set_group,notes,created_at,template_sets(id,template_exercise_id,target_reps,target_weight,target_duration_seconds,order_index),exercises!template_exercises_exercise_id_fkey(id,name,type),exercise_alternatives(order_index,exercises(id,name,type)))',
          );
      final response = requireOwnerAndClient
          ? await query
              .eq('owner', ownerId)
              .eq('clientId', clientId)
              .order('createdAt', ascending: true)
          : await query
              .or('owner.eq.$ownerId,clientId.eq.$clientId')
              .order('createdAt', ascending: true);

      final rawItems = response as List;
      final templates = <RoutineTemplateDto>[];
      for (final item in rawItems) {
        final row = Map<String, dynamic>.from(item as Map);
        templates.add(_convertMapToRoutineTemplateDto(row));
      }
      _templates = templates;

      logger.i('Loaded ${_templates.length} templates from Supabase');
    } catch (e) {
      logger.e('Error loading templates: $e');
      rethrow;
    }
  }

  RoutineTemplateDto _convertMapToRoutineTemplateDto(Map<String, dynamic> row) {
    final templateId = row['id'] as String? ?? '';
    final relationalExerciseRows =
        (row['template_exercises'] as List<dynamic>? ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList()
          ..sort((a, b) {
            final ai = (a['order_index'] as num?)?.toInt() ?? 0;
            final bi = (b['order_index'] as num?)?.toInt() ?? 0;
            return ai.compareTo(bi);
          });

    final exerciseTemplates = relationalExerciseRows
        .map((exerciseRow) => _convertTemplateExerciseRow(
              templateId: templateId,
              row: exerciseRow,
            ))
        .toList();

    return RoutineTemplateDto(
      id: templateId,
      planId: row['planId'] as String? ?? '',
      name: row['name'] as String? ?? '',
      notes: row['notes'] as String? ?? '',
      exerciseTemplates: exerciseTemplates,
      clientId: row['clientId'] as String?,
    );
  }

  ExerciseLogDto _convertTemplateExerciseRow({
    required String templateId,
    required Map<String, dynamic> row,
  }) {
    final exerciseMap = Map<String, dynamic>.from(
      (row['exercises'] as Map?) ?? const {},
    );
    final exerciseType = ExerciseType.fromString(
      exerciseMap['type'] as String? ?? 'NO',
    );
    final exercise = ExerciseDto(
      id: exerciseMap['id'] as String? ?? (row['exercise_id'] as String? ?? ''),
      name: exerciseMap['name'] as String? ?? '',
      type: exerciseType == ExerciseType.none
          ? ExerciseType.weights
          : exerciseType,
      isSystem: true,
    );

    final setRows = (row['template_sets'] as List<dynamic>? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList()
      ..sort((a, b) {
        final ai = (a['order_index'] as num?)?.toInt() ?? 0;
        final bi = (b['order_index'] as num?)?.toInt() ?? 0;
        return ai.compareTo(bi);
      });
    final sets = setRows
        .map((setRow) => _buildTemplateSet(setRow: setRow, type: exercise.type))
        .toList();

    final altRows = (row['exercise_alternatives'] as List<dynamic>? ?? const [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList()
      ..sort((a, b) {
        final ai = (a['order_index'] as num?)?.toInt() ?? 0;
        final bi = (b['order_index'] as num?)?.toInt() ?? 0;
        return ai.compareTo(bi);
      });
    final alternatives = altRows.map((altRow) {
      final exMap = Map<String, dynamic>.from(
        (altRow['exercises'] as Map?) ?? const {},
      );
      final altType = ExerciseType.fromString(exMap['type'] as String? ?? 'NO');
      return ExerciseDto(
        id: exMap['id'] as String? ?? '',
        name: exMap['name'] as String? ?? '',
        type: altType == ExerciseType.none ? ExerciseType.weights : altType,
        isSystem: true,
      );
    }).toList();

    return ExerciseLogDto(
      id: exercise.id,
      routineLogId: templateId,
      superSetId: row['super_set_group'] as String? ?? '',
      exercise: exercise,
      notes: row['notes'] as String? ?? '',
      sets: sets,
      alternatives: alternatives,
      createdAt: DateTime.now(),
    );
  }

  /// Upserts a template to Supabase (routine_templates header +
  /// template_exercises + template_sets). Uses normalized schema.
  Future<void> upsertTemplate({
    required RoutineTemplateDto template,
    required String ownerId,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _client.from('routine_templates').upsert({
      'id': template.id,
      'planId': template.planId,
      'name': template.name,
      'notes': template.notes,
      'clientId': template.clientId,
      'owner': ownerId,
      'createdAt': now,
      'updatedAt': now,
    });

    await _client
        .from('template_exercises')
        .delete()
        .eq('template_id', template.id);

    for (var exIndex = 0; exIndex < template.exerciseTemplates.length; exIndex++) {
      final exLog = template.exerciseTemplates[exIndex];
      final inserted = await _client
          .from('template_exercises')
          .insert({
            'template_id': template.id,
            'exercise_id': exLog.exercise.id,
            'order_index': exIndex,
            'super_set_group':
                exLog.superSetId.isEmpty ? null : exLog.superSetId,
            'notes': exLog.notes.isEmpty ? null : exLog.notes,
          })
          .select('id')
          .single();
      final templateExerciseId = inserted['id'] as String;

      final setRows = <Map<String, dynamic>>[];
      for (var setIndex = 0; setIndex < exLog.sets.length; setIndex++) {
        final set = exLog.sets[setIndex];
        final row = <String, dynamic>{
          'template_exercise_id': templateExerciseId,
          'order_index': setIndex,
        };
        if (set is WeightAndRepsSetDto) {
          row['target_reps'] = set.reps;
          row['target_weight'] = set.weight;
        } else if (set is RepsSetDto) {
          row['target_reps'] = set.reps;
        } else if (set is DurationSetDto) {
          row['target_duration_seconds'] = set.duration.inSeconds;
        }
        setRows.add(row);
      }
      if (setRows.isNotEmpty) {
        await _client.from('template_sets').insert(setRows);
      }

      if (exLog.alternatives.isNotEmpty) {
        final altRows = <Map<String, dynamic>>[];
        for (var altIndex = 0; altIndex < exLog.alternatives.length; altIndex++) {
          altRows.add({
            'template_exercise_id': templateExerciseId,
            'alternative_exercise_id': exLog.alternatives[altIndex].id,
            'order_index': altIndex,
          });
        }
        await _client.from('exercise_alternatives').insert(altRows);
      }
    }
  }

  SetDto _buildTemplateSet({
    required Map<String, dynamic> setRow,
    required ExerciseType type,
  }) {
    final reps = (setRow['target_reps'] as num?)?.toInt() ?? 0;
    final weight = (setRow['target_weight'] as num?)?.toDouble() ?? 0;
    final durationSeconds =
        (setRow['target_duration_seconds'] as num?)?.toInt() ?? 0;
    final now = DateTime.now();

    return switch (type) {
      ExerciseType.weights => WeightAndRepsSetDto(
          weight: weight,
          reps: reps,
          checked: false,
          dateTime: now,
        ),
      ExerciseType.bodyWeight => RepsSetDto(
          reps: reps,
          checked: false,
          dateTime: now,
        ),
      ExerciseType.duration => DurationSetDto(
          duration: Duration(seconds: durationSeconds),
          checked: false,
          dateTime: now,
        ),
      ExerciseType.none => WeightAndRepsSetDto(
          weight: weight,
          reps: reps,
          checked: false,
          dateTime: now,
        ),
    };
  }
}
