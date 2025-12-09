import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';
import 'package:trainware/utils/timezone_utils.dart';
import 'package:timezone/timezone.dart' as tz;

const int notificationIDLongRunningSession = 999;
const String _postWorkoutChannelId = 'post_workout_follow_up';
const String _postWorkoutChannelName = 'Post-workout reminders';
const String _postWorkoutChannelDescription =
    'Reminds you to review or build on your last session.';
const int _defaultPostWorkoutReminderHour = 9;
const Duration _trainingHistoryWindow = Duration(days: 30);
const Duration _trainingHistoryFallbackWindow = Duration(days: 365);
const Duration _calendarHistoryWindow = Duration(days: 14);
const int _calendarWeekdayThreshold = 2;
const String _trainingReminderChannelId = 'preferred_training_reminders';
const String _trainingReminderChannelName = 'Preferred training reminders';
const String _trainingReminderChannelDescription =
    'Nudges you to train on the days and times you usually work out.';

class _ReminderTime {
  final int weekday;
  final int hour;

  _ReminderTime({required this.weekday, required this.hour});

  @override
  String toString() => '$weekday at $hour:00';
}

List<_ReminderTime> _getExerciseReminders(List<DateTime> logDates) {
  if (logDates.isEmpty) return [];

  final now = DateTime.now();
  final primaryCutoff = now.subtract(_trainingHistoryWindow);
  List<DateTime> sourceDates =
      logDates.where((date) => !date.isBefore(primaryCutoff)).toList();

  if (sourceDates.isEmpty) {
    final fallbackCutoff = now.subtract(_trainingHistoryFallbackWindow);
    sourceDates =
        logDates.where((date) => !date.isBefore(fallbackCutoff)).toList();
  }

  if (sourceDates.isEmpty) {
    sourceDates = List<DateTime>.from(logDates);
  }

  // Group exercise hours by weekday
  final Map<int, List<int>> weekdayHours = {};
  for (final logDate in sourceDates) {
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

/// Get likely training weekdays based on the same logic used to schedule
/// preferred training reminders (i.e. any weekday that has historical logs).
/// Returns a Set of weekdays (1-7, where 1 is Monday).
Set<int> getLikelyTrainingWeekdays(
    {required List<DateTime> historicDateTimes}) {
  if (historicDateTimes.isEmpty) return {};

  final reminders = _getExerciseReminders(historicDateTimes);
  return reminders.map((reminder) => reminder.weekday).toSet();
}

/// Determine "likely" training weekdays for calendar surfacing.
/// A weekday qualifies if it has workouts logged on at least two distinct days
/// within the past [_calendarHistoryWindow] (14 days).
Set<int> _getCalendarLikelyTrainingWeekdays(
    {required List<DateTime> historicDateTimes}) {
  if (historicDateTimes.isEmpty) return {};

  final now = DateTime.now();
  final cutoff = DateTime(now.year, now.month, now.day)
      .subtract(_calendarHistoryWindow);
  final Map<int, int> weekdayCounts = {};
  final Set<DateTime> seenDates = <DateTime>{};

  for (final date in historicDateTimes) {
    final normalized = DateTime(date.year, date.month, date.day);
    if (normalized.isBefore(cutoff)) continue;
    if (!seenDates.add(normalized)) continue;
    weekdayCounts[normalized.weekday] =
        (weekdayCounts[normalized.weekday] ?? 0) + 1;
  }

  return weekdayCounts.entries
      .where((entry) => entry.value >= _calendarWeekdayThreshold)
      .map((entry) => entry.key)
      .toSet();
}

/// Get predicted training dates (calendar only) by projecting weekdays that
/// have at least two distinct workout days logged within the past two weeks.
/// Includes today if today matches a likely training weekday.
Set<DateTime> getPredictedTrainingDates({
  required List<DateTime> historicDateTimes,
  int daysAhead = 14,
}) {
  // Calendar predictions only consider weekdays with at least two sessions
  // recorded in the past two weeks to avoid over-highlighting.
  final likelyWeekdays =
      _getCalendarLikelyTrainingWeekdays(historicDateTimes: historicDateTimes);
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

Future<void> schedulePreferredTrainingReminders(
    {required List<DateTime> historicDateTimes}) async {
  if (!Platform.isIOS && !Platform.isAndroid) return;

  final plugin = FlutterLocalNotificationsPlugin();

  // Cancel existing training reminders (IDs 1-7 for weekdays) before rescheduling
  // This prevents duplicate notifications when reminders are rescheduled
  await Future.wait([
    for (int weekday = 1; weekday <= 7; weekday++) plugin.cancel(weekday)
  ]);

  final trainingTimes = _getExerciseReminders(historicDateTimes);
  if (trainingTimes.isEmpty) return;

  final notificationDetails = NotificationDetails(
    android: const AndroidNotificationDetails(
      _trainingReminderChannelId,
      _trainingReminderChannelName,
      channelDescription: _trainingReminderChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    ),
  );

  for (final trainingTime in trainingTimes) {
    final hour = Duration(hours: trainingTime.hour);
    final weekDay = trainingTime.weekday;
    await _scheduleNotification(
      plugin: plugin,
      duration: hour,
      weekday: weekDay,
      details: notificationDetails,
    );
  }
}

Future<void> _scheduleNotification(
    {required FlutterLocalNotificationsPlugin plugin,
    required Duration duration,
    required int weekday,
    required NotificationDetails details}) async {
  final tzDateTime =
      nextInstanceOfHourAndWeekDay(hours: duration.inHours, weekday: weekday);

  const matchDateTimeComponents = DateTimeComponents.dayOfWeekAndTime;

  await plugin.zonedSchedule(
    weekday,
    "Time to Get Moving!",
    "You usually train around this time—let’s keep up the habit and crush today’s workout!",
    tzDateTime,
    details,
    matchDateTimeComponents: matchDateTimeComponents,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  );
}

int _logReminderNotificationId(String logId) => logId.hashCode & 0x7fffffff;

Future<void> schedulePostWorkoutReviewReminder({
  required RoutineLogDto log,
  int reminderHour = _defaultPostWorkoutReminderHour,
}) async {
  if (!Platform.isIOS && !Platform.isAndroid) return;
  if (log.id.isEmpty) return;

  final plugin = FlutterLocalNotificationsPlugin();
  final notificationId = _logReminderNotificationId(log.id);

  // Avoid duplicate reminders if the user edits the same log.
  await plugin.cancel(notificationId);

  final anchorTime =
      log.endTime.isAfter(log.startTime) ? log.endTime : log.startTime;
  final scheduledDate =
      nextMorningAtHour(reference: anchorTime, hour: reminderHour);

  // Guard against scheduling in the past (e.g. if the clock changed)
  if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) {
    return;
  }

  final workoutLabel = log.name.isEmpty ? 'your last workout' : log.name;
  final payload = jsonEncode({
    'type': 'view_log',
    'logId': log.id,
    'isEditable': false,
  });

  const androidDetails = AndroidNotificationDetails(
    _postWorkoutChannelId,
    _postWorkoutChannelName,
    channelDescription: _postWorkoutChannelDescription,
    importance: Importance.defaultImportance,
    priority: Priority.defaultPriority,
  );

  const iOSDetails = DarwinNotificationDetails(
    presentAlert: true,
    presentSound: true,
  );

  await plugin.zonedSchedule(
    notificationId,
    'Nice work yesterday',
    'Jump back in and build on $workoutLabel.',
    scheduledDate,
    const NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    ),
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    payload: payload,
  );
}

Future<void> cancelPostWorkoutReviewReminder(String logId) async {
  if (!Platform.isIOS && !Platform.isAndroid) return;
  if (logId.isEmpty) return;
  await FlutterLocalNotificationsPlugin()
      .cancel(_logReminderNotificationId(logId));
}
