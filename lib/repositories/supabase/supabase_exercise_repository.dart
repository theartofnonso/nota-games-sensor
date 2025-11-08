import 'dart:async';

import 'package:collection/collection.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tracker_app/dtos/appsync/exercise_dto.dart';

import '../../enums/posthog_analytics_event.dart';
import '../../logger.dart';

class SupabaseExerciseRepository {
  final logger = getLogger(className: "SupabaseExerciseRepository");
  final SupabaseClient _client = Supabase.instance.client;

  List<ExerciseDto> _userExercises = [];

  UnmodifiableListView<ExerciseDto> get exercises => UnmodifiableListView(
      _userExercises.sorted((a, b) => a.name.compareTo(b.name)));

  Future<void> loadUserExercises() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        logger.w('No user logged in, cannot load user exercises');
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

      logger.i('Loaded ${_userExercises.length} user exercises');
    } catch (e) {
      logger.e('Error loading user exercises: $e');
      rethrow;
    }
  }

  Future<void> saveExercise({required ExerciseDto exerciseDto}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _client.from('exercises').insert(exerciseDto.toJson());

      Posthog().capture(
        eventName: PostHogAnalyticsEvent.createExercise.displayName,
        properties: Map<String, Object>.from(exerciseDto.toJson()),
      );

      logger.i('Saved exercise: ${exerciseDto.name}');
    } catch (e) {
      logger.e('Error saving exercise: $e');
      rethrow;
    }
  }

  Future<void> updateExercise({required ExerciseDto exercise}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _client
          .from('exercises')
          .update(exercise.toJson())
          .eq('id', exercise.id)
          .eq('owner', userId);

      logger.i('Updated exercise: ${exercise.name}');
    } catch (e) {
      logger.e('Error updating exercise: $e');
      rethrow;
    }
  }

  Future<void> removeExercise({required ExerciseDto exercise}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _client
          .from('exercises')
          .delete()
          .eq('id', exercise.id)
          .eq('owner', userId);

      logger.i('Removed exercise: ${exercise.name}');
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
