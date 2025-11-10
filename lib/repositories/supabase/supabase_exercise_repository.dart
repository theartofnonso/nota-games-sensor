import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:isar/isar.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tracker_app/dtos/appsync/exercise_dto.dart';
import 'package:tracker_app/models/local/local_exercise.dart';
import 'package:tracker_app/services/sync_service.dart';
import 'package:uuid/uuid.dart';

import '../../enums/posthog_analytics_event.dart';
import '../../logger.dart';

class SupabaseExerciseRepository {
  final logger = getLogger(className: "SupabaseExerciseRepository");
  final SupabaseClient _client = Supabase.instance.client;
  final Isar isar;
  final SyncService syncService;

  List<ExerciseDto> _userExercises = [];

  SupabaseExerciseRepository({
    required this.isar,
    required this.syncService,
  });

  UnmodifiableListView<ExerciseDto> get exercises => UnmodifiableListView(
      _userExercises.sorted((a, b) => a.name.compareTo(b.name)));

  /// Load exercises - OFFLINE FIRST
  /// 1. Load from local Isar database immediately
  /// 2. Trigger background sync from Supabase
  Future<void> loadUserExercises() async {
    try {
      // 1. Load from local database first (instant)
      await _loadFromLocal();

      // 2. Trigger background sync (non-blocking)
      _syncFromSupabase();
    } catch (e) {
      logger.e('Error loading user exercises: $e');
      rethrow;
    }
  }

  Future<void> _loadFromLocal() async {
    final localExercises = await isar.localExercises.where().findAll();

    _userExercises = localExercises.map((local) {
      return ExerciseDto.fromJson(jsonDecode(local.jsonData));
    }).toList();

    logger.i('Loaded ${_userExercises.length} exercises from local storage');
  }

  Future<void> _syncFromSupabase() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        logger.w('No user logged in, skipping Supabase sync');
        return;
      }

      if (!await syncService.hasInternet()) {
        logger.d('No internet, skipping Supabase sync');
        return;
      }

      final response = await _client
          .from('exercises')
          .select()
          .eq('owner', userId)
          .order('createdAt', ascending: false);

      final supabaseExercises = (response as List<dynamic>).map((item) {
        return ExerciseDto.fromJson(Map<String, dynamic>.from(item));
      }).toList();

      // Merge with local storage
      await _mergeWithLocal(supabaseExercises);

      // Reload in-memory list after sync
      await _loadFromLocal();

      logger.i('Synced ${supabaseExercises.length} exercises from Supabase');
    } catch (e) {
      logger.e('Error syncing from Supabase: $e');
      // Don't rethrow - local data is already loaded
    }
  }

  Future<void> _mergeWithLocal(List<ExerciseDto> supabaseExercises) async {
    await isar.writeTxn(() async {
      for (final exercise in supabaseExercises) {
        final existing = await isar.localExercises
            .filter()
            .exerciseIdEqualTo(exercise.id)
            .findFirst();

        if (existing == null) {
          // New item - create it
          final local = LocalExercise()
            ..exerciseId = exercise.id
            ..jsonData = jsonEncode(exercise.toJson())
            ..name = exercise.name
            ..type = exercise.type.id
            ..primaryMuscleGroup = exercise.primaryMuscleGroup.name
            ..lastModifiedLocal = DateTime.now()
            ..needsSync = false
            ..createdAt = DateTime.now();

          await isar.localExercises.put(local);
        } else if (!existing.needsSync) {
          // Existing item with no local changes - update from Supabase
          existing
            ..jsonData = jsonEncode(exercise.toJson())
            ..name = exercise.name
            ..type = exercise.type.id
            ..primaryMuscleGroup = exercise.primaryMuscleGroup.name
            ..lastModifiedLocal = DateTime.now()
            ..needsSync = false;

          await isar.localExercises.put(existing);
        }
        // If existing.needsSync = true, keep local version (will sync later)
      }
    });

    // Reload from local
    await _loadFromLocal();
  }

  /// Save exercise - OFFLINE FIRST
  /// 1. Generate temp UUID if needed
  /// 2. Save to local Isar immediately
  /// 3. Add to sync queue
  /// 4. Return immediately (user sees instant feedback)
  Future<ExerciseDto> saveExercise({required ExerciseDto exerciseDto}) async {
    try {
      // Generate UUID if empty
      final id = exerciseDto.id.isEmpty ? const Uuid().v4() : exerciseDto.id;
      final exerciseWithId = exerciseDto.copyWith(id: id);

      // 1. Save to local database immediately
      final local = LocalExercise()
        ..exerciseId = id
        ..jsonData = jsonEncode(exerciseWithId.toJson())
        ..name = exerciseWithId.name
        ..type = exerciseWithId.type.id
        ..primaryMuscleGroup = exerciseWithId.primaryMuscleGroup.name
        ..lastModifiedLocal = DateTime.now()
        ..needsSync = true
        ..createdAt = DateTime.now();

      await isar.writeTxn(() async {
        await isar.localExercises.put(local);
      });

      // 2. Add to in-memory list
      _userExercises.add(exerciseWithId);

      // 3. Queue for background sync
      await syncService.queueSync(
        entityType: 'exercise',
        entityId: id,
        operation: 'create',
        jsonData: jsonEncode(exerciseWithId.toJson()),
      );

      Posthog().capture(
        eventName: PostHogAnalyticsEvent.createExercise.displayName,
        properties: Map<String, Object>.from(exerciseWithId.toJson()),
      );

      logger.i('Saved exercise locally: ${exerciseWithId.name}');
      return exerciseWithId;
    } catch (e) {
      logger.e('Error saving exercise: $e');
      rethrow;
    }
  }

  /// Update exercise - OFFLINE FIRST
  Future<void> updateExercise({required ExerciseDto exercise}) async {
    try {
      // 1. Update local database immediately
      final local = await isar.localExercises
          .filter()
          .exerciseIdEqualTo(exercise.id)
          .findFirst();

      if (local != null) {
        local
          ..jsonData = jsonEncode(exercise.toJson())
          ..name = exercise.name
          ..type = exercise.type.id
          ..primaryMuscleGroup = exercise.primaryMuscleGroup.name
          ..lastModifiedLocal = DateTime.now()
          ..needsSync = true;

        await isar.writeTxn(() async {
          await isar.localExercises.put(local);
        });
      }

      // 2. Update in-memory list
      final index = _userExercises.indexWhere((e) => e.id == exercise.id);
      if (index != -1) {
        _userExercises[index] = exercise;
      }

      // 3. Queue for background sync
      await syncService.queueSync(
        entityType: 'exercise',
        entityId: exercise.id,
        operation: 'update',
        jsonData: jsonEncode(exercise.toJson()),
      );

      logger.i('Updated exercise locally: ${exercise.name}');
    } catch (e) {
      logger.e('Error updating exercise: $e');
      rethrow;
    }
  }

  /// Remove exercise - OFFLINE FIRST
  Future<void> removeExercise({required ExerciseDto exercise}) async {
    try {
      // 1. Remove from local database immediately
      final local = await isar.localExercises
          .filter()
          .exerciseIdEqualTo(exercise.id)
          .findFirst();

      if (local != null) {
        await isar.writeTxn(() async {
          await isar.localExercises.delete(local.id);
        });
      }

      // 2. Remove from in-memory list
      _userExercises.removeWhere((e) => e.id == exercise.id);

      // 3. Queue for background sync (delete from Supabase)
      await syncService.queueSync(
        entityType: 'exercise',
        entityId: exercise.id,
        operation: 'delete',
        jsonData: jsonEncode(exercise.toJson()),
      );

      logger.i('Removed exercise locally: ${exercise.name}');
    } catch (e) {
      logger.e('Error removing exercise: $e');
      rethrow;
    }
  }

  /// Helper methods

  ExerciseDto? whereExercise({required String exerciseId}) {
    return exercises.firstWhereOrNull((exercise) => exercise.id == exerciseId);
  }

  void clear() {
    _userExercises.clear();
  }
}
