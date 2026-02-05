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
        'startTime': map['startTime'],
        'endTime': map['endTime'],
        'exercises': map['exercises'] ?? [],
        'coach_note': map['coach_note'],
      };

      return RoutineLogDto.fromJson(json: data);
    } catch (e) {
      logger.e('Error converting map to RoutineLogDto: $e');
      rethrow;
    }
  }

  /// Updates only the coach_note for a log (used by coaches). Does not touch
  /// exercises, times, or other fields. Throws if no row was updated (e.g. RLS).
  Future<void> updateCoachNote({
    required String logId,
    required String? note,
  }) async {
    final res = await _client.from('routine_logs').update({
      'coach_note': note?.trim().isEmpty ?? true ? null : note!.trim(),
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', logId).select('id');

    final list = res as List<dynamic>;
    if (list.isEmpty) {
      throw Exception(
        'updateCoachNote: no row updated for logId=$logId (check RLS: coach must have update policy on client logs)',
      );
    }
  }
}
