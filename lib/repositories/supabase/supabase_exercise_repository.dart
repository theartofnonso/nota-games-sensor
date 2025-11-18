import 'dart:async';

import 'package:collection/collection.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/dtos/appsync/exercise_dto.dart';
import 'package:uuid/uuid.dart';

import '../../enums/posthog_analytics_event.dart';
import '../../logger.dart';

class SupabaseExerciseRepository {
  final logger = getLogger(className: "SupabaseExerciseRepository");
  final SupabaseClient _client = Supabase.instance.client;

  List<ExerciseDto> _userExercises = [];

  UnmodifiableListView<ExerciseDto> get exercises => UnmodifiableListView(
      _userExercises.sorted((a, b) => a.name.compareTo(b.name)));

  /// Load exercises from Supabase
  Future<void> loadUserExercises() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        logger.w('No user logged in');
        return;
      }

      final response = await _client
          .from('exercises')
          .select()
          .eq('owner', userId)
          .order('createdAt', ascending: false);

      _userExercises = (response as List<dynamic>).map((item) {
        return ExerciseDto.fromJson(Map<String, dynamic>.from(item));
      }).toList();

      logger.i('Loaded ${_userExercises.length} exercises from Supabase');
    } catch (e) {
      logger.e('Error loading user exercises: $e');
      rethrow;
    }
  }

  /// Save a new exercise
  Future<ExerciseDto> saveExercise(ExerciseDto exercise) async {
    try {
      // Generate ID if empty
      final id = exercise.id.isEmpty ? const Uuid().v4() : exercise.id;
      final exerciseWithId = exercise.copyWith(id: id);

      // Insert into Supabase
      await _client.from('exercises').insert(exerciseWithId.toJson());

      // Analytics
      await Posthog().capture(
        eventName: PostHogAnalyticsEvent.createExercise.displayName,
      );

      // Add to in-memory list
      _userExercises.add(exerciseWithId);

      logger.i('Saved exercise: ${exerciseWithId.id}');

      return exerciseWithId;
    } catch (e) {
      logger.e('Error saving exercise: $e');
      rethrow;
    }
  }

  /// Update an existing exercise
  Future<void> updateExercise(ExerciseDto exercise) async {
    try {
      // Update in Supabase
      await _client
          .from('exercises')
          .update(exercise.toJson())
          .eq('id', exercise.id);

      // Update in-memory list
      _userExercises = _userExercises
          .map((item) => item.id == exercise.id ? exercise : item)
          .toList();

      logger.i('Updated exercise: ${exercise.id}');
    } catch (e) {
      logger.e('Error updating exercise: $e');
      rethrow;
    }
  }

  /// Delete an exercise
  Future<void> deleteExercise(ExerciseDto exercise) async {
    try {
      // Delete from Supabase
      await _client.from('exercises').delete().eq('id', exercise.id);

      // Remove from in-memory list
      _userExercises.removeWhere((item) => item.id == exercise.id);

      logger.i('Deleted exercise: ${exercise.id}');
    } catch (e) {
      logger.e('Error deleting exercise: $e');
      rethrow;
    }
  }

  /// Helper: Find exercise by ID
  ExerciseDto? whereExerciseById(String id) {
    return _userExercises.firstWhereOrNull((exercise) => exercise.id == id);
  }

  /// Helper: Find exercise by name
  ExerciseDto? whereExerciseByName(String name) {
    return _userExercises.firstWhereOrNull(
      (exercise) => exercise.name.toLowerCase() == name.toLowerCase(),
    );
  }
}
