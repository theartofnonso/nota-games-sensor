import 'dart:async';

import 'package:collection/collection.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/dtos/appsync/exercise_dto.dart';

import '../../logger.dart';

class SupabaseExerciseRepository {
  final logger = getLogger(className: "SupabaseExerciseRepository");
  final SupabaseClient _client = Supabase.instance.client;

  List<ExerciseDto> _userExercises = [];

  UnmodifiableListView<ExerciseDto> get exercises => UnmodifiableListView(
      _userExercises.sorted((a, b) => a.name.compareTo(b.name)));

  /// Load exercises from Supabase (read-only; writes go through offline layer).
  Future<void> loadUserExercises({String? userIdOverride}) async {
    try {
      final userId = userIdOverride ?? _client.auth.currentUser?.id;
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
}
