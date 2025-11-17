import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:tracker_app/utils/timezone_utils.dart';

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

/// Get likely training weekdays based on historic log patterns
/// Returns a Set of weekdays (1-7, where 1 is Monday) that the user typically trains on
Set<int> getLikelyTrainingWeekdays({required List<DateTime> historicDateTimes}) {
  if (historicDateTimes.isEmpty) return {};

  // Group logs by weekday
  final Map<int, int> weekdayCounts = {};
  for (final logDate in historicDateTimes) {
    final weekday = logDate.weekday;
    weekdayCounts[weekday] = (weekdayCounts[weekday] ?? 0) + 1;
  }

  if (weekdayCounts.isEmpty) return {};

  // Calculate average count per weekday
  final totalCount = weekdayCounts.values.reduce((a, b) => a + b);
  final averageCount = totalCount / weekdayCounts.length;

  // Include weekdays that have at least 50% of the average count (indicating a pattern)
  final likelyWeekdays = <int>{};
  weekdayCounts.forEach((weekday, count) {
    if (count >= (averageCount * 0.5)) {
      likelyWeekdays.add(weekday);
    }
  });

  return likelyWeekdays;
}

/// Get predicted training dates in the next N days based on weekday patterns
/// Includes today if today matches a likely training weekday
Set<DateTime> getPredictedTrainingDates({
  required List<DateTime> historicDateTimes,
  int daysAhead = 14,
}) {
  final likelyWeekdays = getLikelyTrainingWeekdays(historicDateTimes: historicDateTimes);
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

void schedulePreferredTrainingReminders({required List<DateTime> historicDateTimes}) {
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

Future<void> _scheduleNotification({required Duration duration, required int weekday}) async {
  final tzDateTime = nextInstanceOfHourAndWeekDay(hours: duration.inHours, weekday: weekday);

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
