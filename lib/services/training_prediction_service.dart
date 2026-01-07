import 'package:flutter/material.dart';
import '../dtos/appsync/routine_log_dto.dart';

/// Result of finding the next predicted training session
class NextPredictedSession {
  final DateTime date;
  final TimeOfDay time;
  final int daysUntilNext;

  const NextPredictedSession({
    required this.date,
    required this.time,
    required this.daysUntilNext,
  });
}

/// Service for predicting training sessions based on historical data.
/// This service provides unified logic for:
/// - Determining predicted training dates
/// - Deriving typical training times for weekdays
/// - Finding the next predicted session (date + time)
/// 
/// Used by:
/// - Training reminder notifications
/// - Calendar predicted days
/// - Settings frosted cards (next session prediction)
class TrainingPredictionService {
  // Constants matching the calendar prediction logic
  static const Duration _historyWindow = Duration(days: 30);
  static const int _weekdayThreshold = 3; // At least 3 sessions per weekday

  /// Get predicted training dates by projecting weekdays that have 3+ sessions
  /// in the last 30 days. Includes today if it matches a likely training weekday.
  /// 
  /// [historicDateTimes] - List of historical training session start times
  /// [daysAhead] - How many days ahead to predict (default: 14)
  /// 
  /// Returns a set of normalized DateTime objects (date only, time set to 00:00)
  static Set<DateTime> getPredictedTrainingDates({
    required List<DateTime> historicDateTimes,
    int daysAhead = 14,
  }) {
    final likelyWeekdays = _getLikelyTrainingWeekdays(
      historicDateTimes: historicDateTimes,
    );
    if (likelyWeekdays.isEmpty) return {};

    final today = DateTime.now();
    final predictedDates = <DateTime>{};

    for (int i = 0; i <= daysAhead; i++) {
      final date = today.add(Duration(days: i));
      final dateNormalized = DateTime(date.year, date.month, date.day);
      if (likelyWeekdays.contains(date.weekday)) {
        predictedDates.add(dateNormalized);
      }
    }

    return predictedDates;
  }

  /// Determine "likely" training weekdays by looking at the last 30 days
  /// and identifying weekdays that have at least 3 sessions.
  /// 
  /// [historicDateTimes] - List of historical training session start times
  /// 
  /// Returns a set of weekdays (1-7, where 1 is Monday)
  static Set<int> _getLikelyTrainingWeekdays({
    required List<DateTime> historicDateTimes,
  }) {
    if (historicDateTimes.isEmpty) return {};

    final today = DateTime.now();
    final todayNormalized = DateTime(today.year, today.month, today.day);
    final cutoff = todayNormalized.subtract(_historyWindow);

    // Count distinct dates per weekday within the last 30 days
    final Map<int, int> weekdayCounts = {};
    final Set<DateTime> seenDates = <DateTime>{};

    for (final date in historicDateTimes) {
      final normalized = DateTime(date.year, date.month, date.day);
      if (normalized.isBefore(cutoff)) continue;
      if (!seenDates.add(normalized)) continue; // Count each date only once

      weekdayCounts[normalized.weekday] =
          (weekdayCounts[normalized.weekday] ?? 0) + 1;
    }

    // Return weekdays with 3+ sessions
    return weekdayCounts.entries
        .where((entry) => entry.value >= _weekdayThreshold)
        .map((entry) => entry.key)
        .toSet();
  }

  /// Derive the typical training time for a given weekday based on historical logs.
  /// Only considers logs from the last 30 days and requires at least 3 sessions
  /// on that weekday to return a time.
  /// 
  /// [logs] - List of routine logs
  /// [weekday] - Weekday (1-7, where 1 is Monday)
  /// 
  /// Returns the average time of day for that weekday, or null if insufficient data
  static TimeOfDay? deriveTypicalTimeForWeekday(
    List<RoutineLogDto> logs,
    int weekday,
  ) {
    final now = DateTime.now();
    final todayNormalized = DateTime(now.year, now.month, now.day);
    final cutoff = todayNormalized.subtract(_historyWindow);

    // Filter to only logs from the last 30 days on this weekday
    final recentMatches = logs.where((log) {
      final logDate = DateTime(
        log.startTime.year,
        log.startTime.month,
        log.startTime.day,
      );
      return log.startTime.weekday == weekday && !logDate.isBefore(cutoff);
    }).toList();

    // Count distinct dates (same as _getLikelyTrainingWeekdays logic)
    final Set<DateTime> seenDates = <DateTime>{};
    final distinctSessions = <RoutineLogDto>[];

    for (final log in recentMatches) {
      final normalized = DateTime(
        log.startTime.year,
        log.startTime.month,
        log.startTime.day,
      );
      if (seenDates.add(normalized)) {
        distinctSessions.add(log);
      }
    }

    if (distinctSessions.length < _weekdayThreshold) {
      return null;
    }

    // Calculate average time
    final totalMinutes = distinctSessions.fold<int>(
      0,
      (sum, log) => sum + log.startTime.hour * 60 + log.startTime.minute,
    );
    final averageMinutes = totalMinutes ~/ distinctSessions.length;
    final hour = averageMinutes ~/ 60;
    final minute = averageMinutes % 60;

    return TimeOfDay(hour: hour, minute: minute);
  }

  /// Find the next predicted training session (date + time) based on historical logs.
  /// 
  /// This method:
  /// 1. Gets predicted training dates using the unified logic
  /// 2. Filters out dates that already have logs
  /// 3. Finds the next future date
  /// 4. Derives the typical time for that weekday
  /// 5. Only returns if the target datetime is in the future
  /// 
  /// [logs] - List of routine logs
  /// [daysAhead] - How many days ahead to look for predictions (default: end of year)
  /// 
  /// Returns the next predicted session, or null if none found
  static NextPredictedSession? getNextPredictedSession(
    List<RoutineLogDto> logs, {
    int? daysAhead,
  }) {
    if (logs.isEmpty) return null;

    // Create a set of dates that already have logs (normalized to day level)
    final loggedDates = logs.map((log) {
      final date = log.startTime;
      return DateTime(date.year, date.month, date.day);
    }).toSet();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final endOfYear = DateTime(now.year, 12, 31);
    final predictionDaysAhead =
        daysAhead ?? endOfYear.difference(todayStart).inDays;

    final predictedSet = getPredictedTrainingDates(
      historicDateTimes: logs.map((log) => log.startTime).toList(),
      daysAhead: predictionDaysAhead,
    );

    // Filter out predicted dates that already have logs
    final predictedDaysWithoutLogs = predictedSet
        .where((date) => !loggedDates.contains(date))
        .toList()
      ..sort((a, b) => a.compareTo(b));

    if (predictedDaysWithoutLogs.isEmpty) {
      return null;
    }

    // Find the next predicted session with exact start time
    // Only consider future sessions (including today if time hasn't passed)
    DateTime? nextDate;
    TimeOfDay? time;
    int? daysUntilNext;

    // Check if today is predicted and if the typical time is still in the future
    final isTodayPredicted = predictedDaysWithoutLogs.contains(todayStart);
    if (isTodayPredicted) {
      final todayTime = deriveTypicalTimeForWeekday(logs, todayStart.weekday);
      if (todayTime != null) {
        final todayTargetDateTime = DateTime(
          now.year,
          now.month,
          now.day,
          todayTime.hour,
          todayTime.minute,
        );
        // Only use today if the target time is still in the future
        if (todayTargetDateTime.isAfter(now)) {
          nextDate = todayStart;
          time = todayTime;
          daysUntilNext = 0;
        }
      }
    }

    // If today's session time has passed or today isn't predicted,
    // find the next future predicted date
    if (nextDate == null) {
      final futurePredictedDates = predictedDaysWithoutLogs
          .where((date) =>
              date.isAfter(todayStart) ||
              (date == todayStart && !isTodayPredicted))
          .toList();

      if (futurePredictedDates.isNotEmpty) {
        nextDate = futurePredictedDates.first;
        time = deriveTypicalTimeForWeekday(logs, nextDate.weekday);
        if (time != null) {
          final targetDateTime = DateTime(
            nextDate.year,
            nextDate.month,
            nextDate.day,
            time.hour,
            time.minute,
          );
          // Only return if target is in the future
          if (targetDateTime.isAfter(now)) {
            daysUntilNext = nextDate.difference(todayStart).inDays;
          } else {
            // Target time has passed, skip this session
            nextDate = null;
            time = null;
          }
        }
      }
    }

    // If no valid future session found, return null
    if (nextDate == null || time == null) {
      return null;
    }

    return NextPredictedSession(
      date: nextDate,
      time: time,
      daysUntilNext: daysUntilNext ?? 0,
    );
  }

  /// Get all predicted training sessions with their typical times for notification scheduling.
  /// 
  /// This returns a map of weekday -> TimeOfDay for all weekdays that meet the threshold
  /// (3+ sessions in the last 30 days).
  /// 
  /// [logs] - List of routine logs
  /// 
  /// Returns a map where keys are weekdays (1-7) and values are typical training times
  static Map<int, TimeOfDay> getPredictedSessionsForNotifications(
    List<RoutineLogDto> logs,
  ) {
    if (logs.isEmpty) return {};

    final historicDateTimes = logs.map((log) => log.startTime).toList();
    final likelyWeekdays = _getLikelyTrainingWeekdays(
      historicDateTimes: historicDateTimes,
    );

    final Map<int, TimeOfDay> sessions = {};
    for (final weekday in likelyWeekdays) {
      final time = deriveTypicalTimeForWeekday(logs, weekday);
      if (time != null) {
        sessions[weekday] = time;
      }
    }

    return sessions;
  }
}

