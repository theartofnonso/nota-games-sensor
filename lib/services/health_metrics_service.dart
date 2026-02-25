import 'dart:async';
import 'dart:io';

import 'package:health/health.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_flavor.dart';
import '../repositories/supabase/supabase_health_metrics_repository.dart';
import '../shared_prefs.dart';

/// Reads health data from Apple Health (iOS) / Health Connect (Android),
/// syncs to backend, and provides today's values for display.
class HealthMetricsService {
  HealthMetricsService._();
  static final HealthMetricsService instance = HealthMetricsService._();

  final Health _health = Health();
  final SupabaseHealthMetricsRepository _repo =
      SupabaseHealthMetricsRepository();
  bool _configured = false;

  static const _sleepTypes = [
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_AWAKE,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_REM,
  ];


  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// Request authorization for Sleep and Steps. Returns true if granted.
  Future<bool> requestAuthorization() async {
    if (!Platform.isIOS && !Platform.isAndroid) return false;
    await _ensureConfigured();
    final types = [
      HealthDataType.SLEEP_IN_BED,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.SLEEP_AWAKE,
      HealthDataType.SLEEP_DEEP,
      HealthDataType.SLEEP_LIGHT,
      HealthDataType.SLEEP_REM,
      HealthDataType.STEPS,
    ];
    return _health.requestAuthorization(types);
  }

  /// Check if we have permission (has been granted). Best-effort.
  /// On iOS, HealthKit does not disclose READ status, so this may return null.
  Future<bool> hasAuthorization() async {
    if (!Platform.isIOS && !Platform.isAndroid) return false;
    try {
      await _ensureConfigured();
      final types = [
        HealthDataType.SLEEP_IN_BED,
        HealthDataType.STEPS,
      ];
      final result = await _health.hasPermissions(types);
      return result == true;
    } catch (_) {
      return false;
    }
  }

  /// Get today's sleep duration in minutes. Returns 0 if none.
  Future<int> getTodaySleepMinutes() async {
    if (!Platform.isIOS && !Platform.isAndroid) return 0;
    try {
      await _ensureConfigured();
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final data = await _health.getHealthDataFromTypes(
        types: _sleepTypes,
        startTime: midnight,
        endTime: now,
      );
      int totalMinutes = 0;
      for (final dp in data) {
        final mins =
            dp.dateTo.difference(dp.dateFrom).inMinutes;
        totalMinutes += mins;
      }
      return totalMinutes;
    } catch (_) {
      return 0;
    }
  }

  /// Get today's step count. Returns 0 if none.
  Future<int> getTodaySteps() async {
    if (!Platform.isIOS && !Platform.isAndroid) return 0;
    try {
      await _ensureConfigured();
      final now = DateTime.now();
      final midnight = DateTime(now.year, now.month, now.day);
      final steps = await _health.getTotalStepsInInterval(midnight, now);
      return steps ?? 0;
    } catch (_) {
      return 0;
    }
  }

  /// Sync health data to backend. Runs in background, non-blocking.
  /// For client: reads from Health, pushes to backend, backfills missing days.
  /// Call on app load (after auth).
  Future<void> syncToBackend({String? userId}) async {
    if (!AppConfig.isClient) return;
    final uid = userId ?? Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    if (!Platform.isIOS && !Platform.isAndroid) return;
    if (!SharedPrefs().healthAccessGranted) return;

    unawaited(_syncToBackendImpl(uid));
  }

  Future<void> _syncToBackendImpl(String userId) async {
    try {
      await _ensureConfigured();
      final now = DateTime.now();
      final lastSync = SharedPrefs().healthLastSyncDate;
      final from = lastSync ?? now.subtract(const Duration(days: 30));
      final daysToBackfill = now.difference(from).inDays + 1;

      for (var i = 0; i < daysToBackfill; i++) {
        final date = now.subtract(Duration(days: i));
        final midnight = DateTime(date.year, date.month, date.day);
        final endOfDay = midnight.add(const Duration(days: 1));

        int sleepMinutes = 0;
        try {
          final sleepData = await _health.getHealthDataFromTypes(
            types: _sleepTypes,
            startTime: midnight,
            endTime: endOfDay,
          );
          for (final dp in sleepData) {
            sleepMinutes += dp.dateTo.difference(dp.dateFrom).inMinutes;
          }
        } catch (_) {}

        int steps = 0;
        try {
          final s = await _health.getTotalStepsInInterval(midnight, endOfDay);
          steps = s ?? 0;
        } catch (_) {}

        if (sleepMinutes > 0 || steps > 0) {
          await _repo.upsertHealthMetrics(
            userId: userId,
            date: date,
            sleepMinutes: sleepMinutes > 0 ? sleepMinutes : null,
            steps: steps > 0 ? steps : null,
          );
        }
      }

      SharedPrefs().healthLastSyncDate = now;
    } catch (e) {
      // Silent fail - background sync
    }
  }

  /// Fetch health metrics for display (for coach viewing client or client own).
  Future<({int sleepMinutes, int steps})> getMetricsForDate({
    required String userId,
    required DateTime date,
  }) async {
    final fromBackend = await _repo.getHealthMetricsForDate(
      userId: userId,
      date: date,
    );
    if (fromBackend != null) {
      return fromBackend;
    }
    final isOwn =
        userId == Supabase.instance.client.auth.currentUser?.id;
    if (isOwn && (Platform.isIOS || Platform.isAndroid)) {
      final now = DateTime.now();
      final isToday = date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
      if (isToday) {
        final sleep = await getTodaySleepMinutes();
        final steps = await getTodaySteps();
        return (sleepMinutes: sleep, steps: steps);
      }
    }
    return (sleepMinutes: 0, steps: 0);
  }
}
