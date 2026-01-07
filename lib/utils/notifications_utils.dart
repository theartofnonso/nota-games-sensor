import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:trainware/utils/timezone_utils.dart';
import 'package:trainware/services/training_prediction_service.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';

const int notificationIDLongRunningSession = 999;
const String _trainingReminderChannelId = 'preferred_training_reminders';
const String _trainingReminderChannelName = 'Preferred training reminders';
const String _trainingReminderChannelDescription =
    'Nudges you to train on the days and times you usually work out.';

/// Get predicted training dates by projecting weekdays that have 3+ sessions
/// in the last 30 days. Includes today if it matches a likely training weekday.
/// 
/// This is a convenience wrapper around TrainingPredictionService.getPredictedTrainingDates
/// to maintain backward compatibility.
Set<DateTime> getPredictedTrainingDates({
  required List<DateTime> historicDateTimes,
  int daysAhead = 14,
}) {
  return TrainingPredictionService.getPredictedTrainingDates(
    historicDateTimes: historicDateTimes,
    daysAhead: daysAhead,
  );
}

/// Get likely training weekdays based on the same logic used for predictions.
/// Returns a Set of weekdays (1-7, where 1 is Monday).
/// 
/// This uses the unified prediction logic (3+ sessions in last 30 days).
Set<int> getLikelyTrainingWeekdays(
    {required List<DateTime> historicDateTimes}) {
  // Use the prediction service's logic by getting predicted dates and extracting weekdays
  final predictedDates = TrainingPredictionService.getPredictedTrainingDates(
    historicDateTimes: historicDateTimes,
    daysAhead: 7, // Just need to check current week
  );
  
  return predictedDates.map((date) => date.weekday).toSet();
}

/// Schedule training reminder notifications based on predicted training sessions.
/// Uses the unified prediction logic to determine when to send reminders.
/// 
/// [logs] - List of routine logs to analyze for predictions
Future<void> schedulePreferredTrainingReminders({
  required List<RoutineLogDto> logs,
}) async {
  if (!Platform.isIOS && !Platform.isAndroid) return;

  final plugin = FlutterLocalNotificationsPlugin();

  // Cancel existing training reminders (IDs 1-7 for weekdays) before rescheduling
  // This prevents duplicate notifications when reminders are rescheduled
  await Future.wait(
      [for (int weekday = 1; weekday <= 7; weekday++) plugin.cancel(weekday)]);

  // Get predicted sessions using unified prediction logic
  final predictedSessions =
      TrainingPredictionService.getPredictedSessionsForNotifications(logs);
  
  if (predictedSessions.isEmpty) return;

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

  // Schedule notifications for each predicted session
  for (final entry in predictedSessions.entries) {
    final weekday = entry.key;
    final time = entry.value;
    final hour = Duration(hours: time.hour, minutes: time.minute);
    
    await _scheduleNotification(
      plugin: plugin,
      duration: hour,
      weekday: weekday,
      details: notificationDetails,
    );
  }
}

Future<void> _scheduleNotification({
  required FlutterLocalNotificationsPlugin plugin,
  required Duration duration,
  required int weekday,
  required NotificationDetails details,
}) async {
  // Calculate hours and minutes from duration
  final totalMinutes = duration.inMinutes;
  final hours = totalMinutes ~/ 60;
  final minutes = totalMinutes % 60;
  
  final tzDateTime = nextInstanceOfHourAndWeekDay(
    hours: hours,
    weekday: weekday,
    minutes: minutes,
  );

  const matchDateTimeComponents = DateTimeComponents.dayOfWeekAndTime;

  await plugin.zonedSchedule(
    weekday,
    "Time to Get Moving!",
    "You usually train around this time—let's keep up the habit and crush today's workout!",
    tzDateTime,
    details,
    matchDateTimeComponents: matchDateTimeComponents,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  );
}

