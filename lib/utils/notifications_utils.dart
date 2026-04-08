import 'dart:convert';
import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/utils/timezone_utils.dart';
import 'package:trainware/services/training_prediction_service.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';

const int notificationIDLongRunningSession = 999;
const String _trainingReminderChannelId = 'preferred_training_reminders';
const String _trainingReminderChannelName = 'Preferred training reminders';
const String _trainingReminderChannelDescription =
    'Nudges you to train on the days and times you usually work out.';

const String _nutritionNudgeChannelId = 'training_nutrition_nudges';
const String _nutritionNudgeChannelName = 'Training nutrition tips';
const String _nutritionNudgeChannelDescription =
    'Short reminders to fuel and recover around your usual workout times.';

/// Payload type for [onDidReceiveNotificationResponse] → nutrition tracker.
const String nutritionNudgeNotificationPayloadType = 'nutrition_nudge';

/// Base for nutrition nudge IDs. Workout reminders use 1–7; these use 210–273.
int _nutritionNudgeNotificationId(int trainingWeekday, int kind) =>
    200 + trainingWeekday * 10 + kind;

/// Offsets from predicted **session start** (A/B before, C/D after).
const List<Duration> _nutritionNudgeOffsets = [
  Duration(hours: -3, minutes: -30), // pre-training (~3–4 h before)
  Duration(minutes: -75), // pre-workout (60–90 min before)
  Duration(hours: 1, minutes: 30), // post-workout (within ~0–2 h after)
  Duration(hours: 3), // extended recovery (~2–4 h after)
];

const List<String> _nutritionNudgeTitles = [
  'Fuel up for training',
  'Training soon',
  'Recovery starts now',
  'Keep recovering',
];

const List<String> _nutritionNudgeBodies = [
  'Eat a balanced meal with protein and slower carbs before your session.',
  'Keep it light — quick carbs, low fat and fibre before you train.',
  'Prioritise protein and carbs in your next meal.',
  'Protein and carbs still help — eat to support your training.',
];

/// Cancels all training nutrition nudge notifications (IDs 210–273).
Future<void> cancelTrainingNutritionNudges() async {
  if (!Platform.isIOS && !Platform.isAndroid) return;
  final plugin = FlutterLocalNotificationsPlugin();
  final futures = <Future<void>>[];
  for (int w = 1; w <= 7; w++) {
    for (int k = 0; k < _nutritionNudgeOffsets.length; k++) {
      futures.add(plugin.cancel(_nutritionNudgeNotificationId(w, k)));
    }
  }
  await Future.wait(futures);
}

/// Schedules weekly local notifications around predicted training times (client only).
/// Reuses [TrainingPredictionService.getPredictedSessionsForNotifications]; does not
/// duplicate workout reminder IDs (1–7).
Future<void> scheduleTrainingNutritionNudges({
  required List<RoutineLogDto> logs,
}) async {
  if (!AppConfig.isClient) return;
  if (!Platform.isIOS && !Platform.isAndroid) return;

  await ensureLocalTimezoneConfigured();

  final plugin = FlutterLocalNotificationsPlugin();
  await cancelTrainingNutritionNudges();

  final predictedSessions =
      TrainingPredictionService.getPredictedSessionsForNotifications(logs);
  if (predictedSessions.isEmpty) return;

  final payload = jsonEncode(
    <String, dynamic>{'type': nutritionNudgeNotificationPayloadType},
  );

  final details = NotificationDetails(
    android: AndroidNotificationDetails(
      _nutritionNudgeChannelId,
      _nutritionNudgeChannelName,
      channelDescription: _nutritionNudgeChannelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: const DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
    ),
  );

  for (final entry in predictedSessions.entries) {
    final trainingWeekday = entry.key;
    final time = entry.value;
    for (var k = 0; k < _nutritionNudgeOffsets.length; k++) {
      final slot = offsetFromWeeklyTrainingSlot(
        trainingWeekday: trainingWeekday,
        trainingHour: time.hour,
        trainingMinute: time.minute,
        offset: _nutritionNudgeOffsets[k],
      );
      await _scheduleNutritionNudge(
        plugin: plugin,
        id: _nutritionNudgeNotificationId(trainingWeekday, k),
        scheduleWeekday: slot.weekday,
        hour: slot.hour,
        minute: slot.minute,
        title: _nutritionNudgeTitles[k],
        body: _nutritionNudgeBodies[k],
        details: details,
        payload: payload,
      );
    }
  }
}

Future<void> _scheduleNutritionNudge({
  required FlutterLocalNotificationsPlugin plugin,
  required int id,
  required int scheduleWeekday,
  required int hour,
  required int minute,
  required String title,
  required String body,
  required NotificationDetails details,
  required String payload,
}) async {
  final tzDateTime = nextInstanceOfHourAndWeekDay(
    hours: hour,
    weekday: scheduleWeekday,
    minutes: minute,
  );

  await plugin.zonedSchedule(
    id,
    title,
    body,
    tzDateTime,
    details,
    payload: payload,
    matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
  );
}

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

/// Cancels weekday workout reminders (notification IDs 1–7).
Future<void> cancelPreferredTrainingReminders() async {
  if (!Platform.isIOS && !Platform.isAndroid) return;
  final plugin = FlutterLocalNotificationsPlugin();
  await Future.wait(
    [for (int weekday = 1; weekday <= 7; weekday++) plugin.cancel(weekday)],
  );
}

/// Cancels workout reminders and training nutrition nudges (e.g. on logout).
Future<void> cancelAllTrainingRelatedLocalNotifications() async {
  await cancelPreferredTrainingReminders();
  await cancelTrainingNutritionNudges();
}

/// Schedule training reminder notifications based on predicted training sessions.
/// Uses the unified prediction logic to determine when to send reminders.
/// 
/// [logs] - List of routine logs to analyze for predictions
Future<void> schedulePreferredTrainingReminders({
  required List<RoutineLogDto> logs,
}) async {
  if (!Platform.isIOS && !Platform.isAndroid) return;

  await ensureLocalTimezoneConfigured();

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

