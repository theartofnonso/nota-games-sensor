import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:trainware/utils/timezone_utils.dart';

const int notificationIDLongRunningSession = 999;

class _ReminderTime {
  final int weekday;
  final int hour;

  _ReminderTime({required this.weekday, required this.hour});

  @override
  String toString() => '$weekday at $hour:00';
}

List<_ReminderTime> _getExerciseReminders(List<DateTime> logDates) {
  // Group exercise hours by weekday
  final Map<int, List<int>> weekdayHours = {};
  for (final logDate in logDates) {
    final hour = logDate.hour;
    weekdayHours.putIfAbsent(logDate.weekday, () => []).add(hour);
  }

  final List<_ReminderTime> reminders = [];

  // Process each weekday to find most frequent hour
  weekdayHours.forEach((weekday, hours) {
    if (hours.isEmpty) return;

    // Count frequency of each hour
    final hourCounts = <int, int>{};
    for (final hour in hours) {
      hourCounts[hour] = (hourCounts[hour] ?? 0) + 1;
    }

    // Sort hours by frequency (desc) and time (asc)
    final sortedEntries = hourCounts.entries.toList()
      ..sort((a, b) {
        final countCompare = b.value.compareTo(a.value);
        return countCompare != 0 ? countCompare : a.key.compareTo(b.key);
      });

    reminders.add(_ReminderTime(
      weekday: weekday,
      hour: sortedEntries.first.key,
    ));
  });

  reminders.sort((a, b) => a.weekday.compareTo(b.weekday));

  return reminders;
}

/// Heuristic to decide whether a weekday has a consistent training pattern.
///
/// weeksObserved  – number of calendar weeks in the 30‑day window
/// weeksTrained   – number of those weeks where the user trained on this weekday
/// totalLogsLast30 – total number of sessions in the 30‑day window
bool _isConsistentTrainingWeekday({
  required int weeksObserved,
  required int weeksTrained,
  required int totalLogsLast30,
}) {
  if (weeksObserved == 0 || weeksTrained == 0) return false;

  final consistency = weeksTrained / weeksObserved;

  // With extremely little data, don't predict anything.
  if (totalLogsLast30 < 4) return false;

  // With ~4+ weeks of data, require at least 4 training weeks
  // and a reasonably strong pattern (>= 70% of those weekdays).
  if (weeksObserved >= 4) {
    return weeksTrained >= 4 && consistency >= 0.7;
  }

  // With 3 weeks of data, be more strict on ratio.
  if (weeksObserved == 3) {
    return weeksTrained >= 2 && consistency >= (2 / 3);
  }

  // With 2 weeks of data, only trust if both weeks had training.
  if (weeksObserved == 2) {
    return weeksTrained == 2;
  }

  // With only 1 week of data we don't consider the pattern stable enough.
  return false;
}

/// Get likely training weekdays based on historic log patterns over the last 30 days.
/// Returns a Set of weekdays (1-7, where 1 is Monday) that the user consistently trains on.
Set<int> getLikelyTrainingWeekdays(
    {required List<DateTime> historicDateTimes}) {
  if (historicDateTimes.isEmpty) return {};

  // Work with only the last 30 days of training history.
  final now = DateTime.now();
  final rangeEnd = DateTime(now.year, now.month, now.day);
  final rangeStart = rangeEnd.subtract(const Duration(days: 29));

  final windowDates = historicDateTimes
      .map((d) => DateTime(d.year, d.month, d.day))
      .where((d) => !d.isBefore(rangeStart) && !d.isAfter(rangeEnd))
      .toList();

  if (windowDates.isEmpty) return {};

  final totalLogsLast30 = windowDates.length;
  if (totalLogsLast30 < 4) return {};

  // Track, per weekday, which calendar weeks had training.
  final Map<int, Set<int>> weekdayWeeks = {};
  final Set<int> allWeeks = {};

  for (final date in windowDates) {
    // Monday-based week start for this date
    final weekStart =
        date.subtract(Duration(days: date.weekday - DateTime.monday));
    final weekKey =
        DateTime(weekStart.year, weekStart.month, weekStart.day)
            .millisecondsSinceEpoch;

    allWeeks.add(weekKey);
    weekdayWeeks.putIfAbsent(date.weekday, () => <int>{}).add(weekKey);
  }

  final weeksObserved = allWeeks.length;
  if (weeksObserved == 0) return {};

  final likelyWeekdays = <int>{};

  weekdayWeeks.forEach((weekday, weeksSet) {
    final weeksTrained = weeksSet.length;
    if (_isConsistentTrainingWeekday(
      weeksObserved: weeksObserved,
      weeksTrained: weeksTrained,
      totalLogsLast30: totalLogsLast30,
    )) {
      likelyWeekdays.add(weekday);
    }
  });

  // Fallback: if no weekday passes the strict consistency test but we
  // still have a fair amount of data, fall back to the single most
  // consistent weekday with at least 50% of weeks trained.
  if (likelyWeekdays.isEmpty && totalLogsLast30 >= 8) {
    double bestConsistency = 0.0;
    int? bestWeekday;

    weekdayWeeks.forEach((weekday, weeksSet) {
      final weeksTrained = weeksSet.length;
      final consistency = weeksObserved == 0
          ? 0.0
          : weeksTrained / weeksObserved;

      if (consistency >= 0.5 && consistency > bestConsistency) {
        bestConsistency = consistency;
        bestWeekday = weekday;
      }
    });

    if (bestWeekday != null) {
      likelyWeekdays.add(bestWeekday!);
    }
  }

  return likelyWeekdays;
}

/// Get predicted training dates in the next N days based on weekday patterns
/// Includes today if today matches a likely training weekday
Set<DateTime> getPredictedTrainingDates({
  required List<DateTime> historicDateTimes,
  int daysAhead = 14,
}) {
  final likelyWeekdays =
      getLikelyTrainingWeekdays(historicDateTimes: historicDateTimes);
  if (likelyWeekdays.isEmpty) return {};

  final today = DateTime.now();
  final predictedDates = <DateTime>{};

  // Include today (i = 0) and next N days
  for (int i = 0; i <= daysAhead; i++) {
    final date = today.add(Duration(days: i));
    final dateNormalized = DateTime(date.year, date.month, date.day);
    if (likelyWeekdays.contains(date.weekday)) {
      predictedDates.add(dateNormalized);
    }
  }

  return predictedDates;
}

void schedulePreferredTrainingReminders(
    {required List<DateTime> historicDateTimes}) {
  if (Platform.isIOS) {
    // Cancel existing training reminders (IDs 1-7 for weekdays) before rescheduling
    // This prevents duplicate notifications when reminders are rescheduled
    for (int weekday = 1; weekday <= 7; weekday++) {
      FlutterLocalNotificationsPlugin().cancel(weekday);
    }

    final trainingTimes = _getExerciseReminders(historicDateTimes);

    for (final trainingTime in trainingTimes) {
      final hour = Duration(hours: trainingTime.hour);
      final weekDay = trainingTime.weekday;
      _scheduleNotification(duration: hour, weekday: weekDay);
    }
  }
}

Future<void> _scheduleNotification(
    {required Duration duration, required int weekday}) async {
  final tzDateTime =
      nextInstanceOfHourAndWeekDay(hours: duration.inHours, weekday: weekday);

  const matchDateTimeComponents = DateTimeComponents.dayOfWeekAndTime;

  await FlutterLocalNotificationsPlugin().zonedSchedule(
      weekday,
      "Time to Get Moving!",
      "You usually train around this time—let’s keep up the habit and crush today’s workout!",
      tzDateTime,
      const NotificationDetails(),
      matchDateTimeComponents: matchDateTimeComponents,
      androidScheduleMode: AndroidScheduleMode.exact);
}
