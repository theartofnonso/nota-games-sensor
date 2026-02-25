import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase repository for health metrics (sleep, steps).
/// Table: health_metrics (user_id, date, sleep_minutes, steps, created_at, updated_at)
/// Unique on (user_id, date).
class SupabaseHealthMetricsRepository {
  SupabaseClient get _client => Supabase.instance.client;

  /// Upsert health metrics for a user/date. Used when syncing from Apple Health.
  Future<void> upsertHealthMetrics({
    required String userId,
    required DateTime date,
    int? sleepMinutes,
    int? steps,
  }) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    await _client.from('health_metrics').upsert({
      'user_id': userId,
      'date': dateStr,
      if (sleepMinutes != null) 'sleep_minutes': sleepMinutes,
      if (steps != null) 'steps': steps,
      'updated_at': DateTime.now().toIso8601String(),
    }, onConflict: 'user_id,date');
  }

  /// Fetch health metrics for a user on a specific date.
  /// Returns (sleepMinutes, steps) or null if no row.
  Future<({int sleepMinutes, int steps})?> getHealthMetricsForDate({
    required String userId,
    required DateTime date,
  }) async {
    final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final res = await _client
        .from('health_metrics')
        .select('sleep_minutes, steps')
        .eq('user_id', userId)
        .eq('date', dateStr)
        .maybeSingle();
    if (res == null) return null;
    return (
      sleepMinutes: res['sleep_minutes'] as int? ?? 0,
      steps: res['steps'] as int? ?? 0,
    );
  }

  /// Fetch health metrics for a user. Used by coach viewing client or client
  /// viewing own cached data. Returns map of date string -> (sleepMinutes, steps).
  Future<Map<String, ({int sleepMinutes, int steps})>> getHealthMetricsForUser({
    required String userId,
    required DateTime from,
    required DateTime to,
  }) async {
    final fromStr = '${from.year}-${from.month.toString().padLeft(2, '0')}-${from.day.toString().padLeft(2, '0')}';
    final toStr = '${to.year}-${to.month.toString().padLeft(2, '0')}-${to.day.toString().padLeft(2, '0')}';
    final rows = await _client
        .from('health_metrics')
        .select('date, sleep_minutes, steps')
        .eq('user_id', userId)
        .gte('date', fromStr)
        .lte('date', toStr);
    final map = <String, ({int sleepMinutes, int steps})>{};
    for (final r in rows as List) {
      final row = r as Map<String, dynamic>;
      final date = row['date'] as String? ?? '';
      map[date] = (
        sleepMinutes: row['sleep_minutes'] as int? ?? 0,
        steps: row['steps'] as int? ?? 0,
      );
    }
    return map;
  }
}
