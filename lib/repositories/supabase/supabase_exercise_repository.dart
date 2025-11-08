import 'dart:async';
import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tracker_app/dtos/appsync/exercise_dto.dart';

import '../../enums/posthog_analytics_event.dart';
import '../../logger.dart';

class SupabaseExerciseRepository {
  final logger = getLogger(className: "SupabaseExerciseRepository");
  final SupabaseClient _client = Supabase.instance.client;

  List<ExerciseDto> _localExercises = [];
  List<ExerciseDto> _userExercises = [];

  UnmodifiableListView<ExerciseDto> get exercises => UnmodifiableListView([
        ..._localExercises,
        ..._userExercises
      ].sorted((a, b) => a.name.compareTo(b.name)));

  Future<List<ExerciseDto>> _loadFromAssets({required String file}) async {
    String jsonString = await rootBundle.loadString('exercises/$file');
    final exerciseJsons = json.decode(jsonString) as List<dynamic>;
    return exerciseJsons
        .map((json) => ExerciseDto.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  Future<void> loadLocalExercises() async {
    List<ExerciseDto> exerciseDtos = [];
    final chestExercises = await _loadFromAssets(file: 'chest_exercises.json');
    final shouldersExercises =
        await _loadFromAssets(file: 'shoulders_exercises.json');
    final bicepsExercises =
        await _loadFromAssets(file: 'biceps_exercises.json');
    final tricepsExercises =
        await _loadFromAssets(file: 'triceps_exercises.json');
    final quadricepsExercises =
        await _loadFromAssets(file: 'quadriceps_exercises.json');
    final hamstringsExercises =
        await _loadFromAssets(file: 'hamstrings_exercises.json');
    final backExercises = await _loadFromAssets(file: 'back_exercises.json');
    final trapsExercises = await _loadFromAssets(file: 'traps_exercises.json');
    final latsExercises = await _loadFromAssets(file: 'lats_exercises.json');
    final glutesExercises =
        await _loadFromAssets(file: 'glutes_exercises.json');
    final adductorsExercises =
        await _loadFromAssets(file: 'adductors_exercises.json');
    final abductorsExercises =
        await _loadFromAssets(file: 'abductors_exercises.json');
    final absExercises = await _loadFromAssets(file: 'abs_exercises.json');
    final calvesExercises =
        await _loadFromAssets(file: 'calves_exercises.json');
    final forearmsExercises =
        await _loadFromAssets(file: 'forearms_exercises.json');
    final neckExercises = await _loadFromAssets(file: 'neck_exercises.json');
    final fullBodyExercises =
        await _loadFromAssets(file: 'fullbody_exercises.json');

    exerciseDtos.addAll(chestExercises);
    exerciseDtos.addAll(shouldersExercises);
    exerciseDtos.addAll(bicepsExercises);
    exerciseDtos.addAll(tricepsExercises);
    exerciseDtos.addAll(quadricepsExercises);
    exerciseDtos.addAll(hamstringsExercises);
    exerciseDtos.addAll(backExercises);
    exerciseDtos.addAll(trapsExercises);
    exerciseDtos.addAll(latsExercises);
    exerciseDtos.addAll(glutesExercises);
    exerciseDtos.addAll(adductorsExercises);
    exerciseDtos.addAll(abductorsExercises);
    exerciseDtos.addAll(absExercises);
    exerciseDtos.addAll(calvesExercises);
    exerciseDtos.addAll(forearmsExercises);
    exerciseDtos.addAll(neckExercises);
    exerciseDtos.addAll(fullBodyExercises);

    _localExercises = exerciseDtos;
  }

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
          .order('created_at', ascending: false);

      _userExercises = (response as List<dynamic>).map((item) {
        final dataJson =
            jsonDecode(item['data'] as String) as Map<String, dynamic>;
        dataJson['id'] = item['id'];
        dataJson['owner'] = item['owner'];
        dataJson['createdAt'] = item['created_at'];
        dataJson['updatedAt'] = item['updated_at'];
        return ExerciseDto.fromJson(dataJson);
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

      final now = DateTime.now().toUtc();

      final insertData = {
        'owner': userId,
        'data': jsonEncode(exerciseDto.toJson()),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      // Only include id if it's not empty (let Supabase auto-generate otherwise)
      if (exerciseDto.id.isNotEmpty) {
        insertData['id'] = exerciseDto.id;
      }

      await _client.from('exercises').insert(insertData);

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

      final now = DateTime.now().toUtc();

      await _client
          .from('exercises')
          .update({
            'data': jsonEncode(exercise.toJson()),
            'updated_at': now.toIso8601String(),
          })
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
    _localExercises.clear();
    _userExercises.clear();
  }
}
