import 'dart:collection';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/dtos/nutrition/nutrition_log_dto.dart';

import '../../logger.dart';

class SupabaseNutritionLogRepository {
  final logger = getLogger(className: 'SupabaseNutritionLogRepository');
  final SupabaseClient _client = Supabase.instance.client;

  List<NutritionLogDto> _logs = [];

  UnmodifiableListView<NutritionLogDto> get logs => UnmodifiableListView(_logs);

  Future<void> loadLogs() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        logger.w('No user logged in');
        return;
      }

      final response = await _client
          .from('nutrition_logs')
          .select()
          .eq('user_id', userId)
          .order('logged_at', ascending: false);

      _logs = (response as List<dynamic>)
          .map((item) =>
              NutritionLogDto.fromJson(json: item as Map<String, dynamic>))
          .toList();

      logger.i('Loaded ${_logs.length} nutrition logs from Supabase');
    } catch (e) {
      logger.e('Error loading nutrition logs: $e');
      rethrow;
    }
  }
}
