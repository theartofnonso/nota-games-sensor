import 'dart:async';
import 'dart:collection';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';

import '../../logger.dart';

class SupabaseRoutineLogRepository {
  final logger = getLogger(className: "SupabaseRoutineLogRepository");
  final SupabaseClient _client = Supabase.instance.client;

  List<RoutineLogDto> _logs = [];

  UnmodifiableListView<RoutineLogDto> get logs => UnmodifiableListView(_logs);

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
}
