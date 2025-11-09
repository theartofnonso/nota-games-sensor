import 'dart:async';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tracker_app/dtos/appsync/routine_log_dto.dart';
import 'package:tracker_app/enums/muscle_group_enums.dart';
import 'package:tracker_app/extensions/datetime/datetime_extension.dart';
import 'package:tracker_app/utils/exercise_logs_utils.dart';
import 'package:tracker_app/utils/routine_utils.dart';

import '../../dtos/appsync/exercise_dto.dart';
import '../../dtos/exercise_log_dto.dart';
import '../../dtos/set_dtos/set_dto.dart';
import '../../enums/posthog_analytics_event.dart';
import '../../logger.dart';
import '../../utils/date_utils.dart';
import '../../utils/notifications_utils.dart';

class SupabaseRoutineLogRepository {
  final logger = getLogger(className: "SupabaseRoutineLogRepository");
  final SupabaseClient _client = Supabase.instance.client;

  List<RoutineLogDto> _logs = [];

  UnmodifiableListView<RoutineLogDto> get logs => UnmodifiableListView(_logs);

  Map<String, List<ExerciseLogDto>> _exerciseLogsByExerciseId = {};

  UnmodifiableMapView<String, List<ExerciseLogDto>>
      get exerciseLogsByExerciseId =>
          UnmodifiableMapView(_exerciseLogsByExerciseId);

  Map<MuscleGroup, List<ExerciseLogDto>> _exerciseLogsByMuscleGroup = {};

  UnmodifiableMapView<MuscleGroup, List<ExerciseLogDto>>
      get exerciseLogsByMuscleGroup =>
          UnmodifiableMapView(_exerciseLogsByMuscleGroup);

  void _groupExerciseLogsById() {
    _exerciseLogsByExerciseId =
        groupExerciseLogsByExerciseId(routineLogs: _logs);
  }

  void _groupExerciseLogsByMuscleGroup() {
    _exerciseLogsByMuscleGroup =
        groupExerciseLogsByMuscleGroup(routineLogs: _logs);
  }

  Future<void> loadLogs() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        logger.w('No user logged in, cannot load logs');
        return;
      }

      final response = await _client
          .from('routine_logs')
          .select()
          .eq('owner', userId)
          .order('createdAt', ascending: false);

      _logs = (response as List<dynamic>)
          .map((item) => _convertMapToRoutineLogDto(item))
          .toList();

      _syncTrainingReminders();
      _groupExerciseLogsById();
      _groupExerciseLogsByMuscleGroup();

      logger.i('Loaded ${_logs.length} routine logs');
    } catch (e) {
      logger.e('Error loading routine logs: $e');
      rethrow;
    }
  }

  /// Everytime we sync logs, we refresh the training reminders
  /// First we cancel all notifications previously set when we supported daily notifications,
  /// then pending workout sessions and
  /// also, stale training reminders, because training frequency changes
  /// Finally, schedule notification reminders for those dates and time

  void _syncTrainingReminders() {
    if (logs.isEmpty) return;

    if (Platform.isIOS) {
      final dateRange = theLastYearDateTimeRange();
      final weeksInLastYear = generateWeeksInRange(range: dateRange);

      List<DateTime> historicTrainingTimes = [];
      for (final week in weeksInLastYear) {
        final startOfWeek = week.start;
        final endOfWeek = week.end;

        final weeklyLogs = _logs.where((log) =>
            log.startTime.isBetweenInclusive(from: startOfWeek, to: endOfWeek));

        final weeklyLogsTimes = weeklyLogs.map((log) {
          final startTime = log.startTime;
          final logDuration = log.duration();
          return startTime.subtract(logDuration);
        });

        historicTrainingTimes.addAll(weeklyLogsTimes);
      }
      FlutterLocalNotificationsPlugin().cancelAll();

      schedulePreferredTrainingReminders(
          historicDateTimes: historicTrainingTimes);
    }
  }

  Future<RoutineLogDto> saveLog(
      {required RoutineLogDto logDto, DateTime? datetime}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      final response = await _client
          .from('routine_logs')
          .insert(logDto.toJson())
          .select()
          .single();

      final generatedId = response['id'] as String;

      logger.i('Saved log: ${logDto.name}');

      Posthog().capture(
          eventName: PostHogAnalyticsEvent.logRoutine.displayName,
          properties: Map<String, Object>.from(logDto.toJson()));

      final updatedRoutineLogWithId = logDto.copyWith(id: generatedId);
      final updatedRoutineWithExerciseIds = updatedRoutineLogWithId.copyWith(
          exerciseLogs: updatedRoutineLogWithId.exerciseLogs
              .map((log) => log.copyWith(routineLogId: generatedId))
              .toList());

      return updatedRoutineWithExerciseIds;
    } catch (e) {
      logger.e('Error saving log: $e');
      rethrow;
    }
  }

  Future<void> updateLog({required RoutineLogDto log}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _client
          .from('routine_logs')
          .update(log.toJson())
          .eq('id', log.id)
          .eq('owner', userId);

      logger.i('Updated log: ${log.name}');
    } catch (e) {
      logger.e('Error updating log: $e');
      rethrow;
    }
  }

  Future<void> removeLog({required RoutineLogDto log}) async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception('User not authenticated');
      }

      await _client
          .from('routine_logs')
          .delete()
          .eq('id', log.id)
          .eq('owner', userId);

      logger.i('Removed log: ${log.name}');
    } catch (e) {
      logger.e('Error removing log: $e');
      rethrow;
    }
  }

  /// Helper methods

  RoutineLogDto? logWhereId({required String id}) {
    return _logs.firstWhereOrNull((log) => log.id == id);
  }

  /// Returns all *checked, non-empty* sets from the most-recent `take` logs
  /// of a given exercise. If `take` is null, the entire history is scanned.
  List<SetDto> wherePrevSetsForExercise({
    required ExerciseDto exercise,
    int? take,
  }) {
    // 1️⃣  Fast-return if we have no logs for this exercise id.
    final logs = _exerciseLogsByExerciseId[exercise.id];
    if (logs == null || logs.isEmpty) return const [];

    // 2️⃣  Iterate in reverse order to get "latest first".
    final Iterable<ExerciseLogDto> recent =
        take == null ? logs.reversed : logs.reversed.take(take);

    // 3️⃣  Use a single list-comprehension to avoid multiple temporary lists.
    return [
      for (final log in recent)
        for (final set in log.sets)
          if (set.checked && set.isNotEmpty()) set,
    ];
  }

  List<SetDto> wherePrevSetsGroupForIndex({
    required ExerciseDto exercise,
    required int index,
    int? take,
  }) {
    if (index < 0) return const [];

    final logs = _exerciseLogsByExerciseId[exercise.id];
    if (logs == null || logs.isEmpty) return const [];

    // newest → oldest, optionally limited by `take`
    final Iterable<ExerciseLogDto> recent =
        take == null ? logs.reversed : logs.reversed.take(take);

    final result = <SetDto>[];
    for (final log in recent) {
      // only pick from logs that contain that index
      if (index < log.sets.length) result.add(log.sets[index]);
    }
    return result;
  }

  List<SetDto> whereRecentSetsForExercise({required ExerciseDto exercise}) {
    final exerciseLogs = _exerciseLogsByExerciseId[exercise.id]?.reversed ?? [];
    final completedExercises =
        loggedExercises(exerciseLogs: exerciseLogs.toList());
    return completedExercises.isNotEmpty ? completedExercises.first.sets : [];
  }

  List<SetDto> whereSetsForExerciseBefore(
      {required ExerciseDto exercise, required DateTime date}) {
    final exerciseLogs = _exerciseLogsByExerciseId[exercise.id]
            ?.where((log) => log.createdAt.isBefore(date)) ??
        [];
    final completedExercises =
        loggedExercises(exerciseLogs: exerciseLogs.toList());
    return completedExercises.isNotEmpty ? completedExercises.first.sets : [];
  }

  List<ExerciseLogDto> whereExerciseLogsBefore(
      {required ExerciseDto exercise, required DateTime date}) {
    final exerciseLogs = _exerciseLogsByExerciseId[exercise.id]
            ?.where((log) => log.createdAt.isBefore(date))
            .toList() ??
        [];
    final completedExercises =
        loggedExercises(exerciseLogs: exerciseLogs.toList());
    return completedExercises;
  }

  /// RoutineLog for the following [DateTime]
  /// Day, Month and Year - Looking for a log in the same day, hence the need to match the day, month and year
  /// Month and Year - Looking for a log in the same month day, hence the need to match the month and year
  /// Year - Looking for a log in the same year, hence the need to match the year
  RoutineLogDto? whereLogIsSameDay({required DateTime dateTime}) {
    return _logs
        .firstWhereOrNull((log) => log.startTime.isSameDayMonthYear(dateTime));
  }

  RoutineLogDto? whereLogIsSameMonth({required DateTime dateTime}) {
    return _logs
        .firstWhereOrNull((log) => log.startTime.isSameMonthYear(dateTime));
  }

  RoutineLogDto? whereLogIsSameYear({required DateTime dateTime}) {
    return _logs.firstWhereOrNull((log) => log.startTime.isSameYear(dateTime));
  }

  /// RoutineLogs for the following [DateTime]
  /// Day, Month and Year - Looking for logs in the same day, hence the need to match the day, month and year
  /// Month and Year - Looking for logs in the same month day, hence the need to match the month and year
  /// Year - Looking for logs in the same year, hence the need to match the year
  List<RoutineLogDto> whereLogsIsSameDay({required DateTime dateTime}) {
    return _logs
        .where((log) => log.startTime.isSameDayMonthYear(dateTime))
        .toList();
  }

  List<RoutineLogDto> whereLogsIsSameMonth({required DateTime dateTime}) {
    return _logs
        .where((log) => log.startTime.isSameMonthYear(dateTime))
        .toList();
  }

  List<RoutineLogDto> whereLogsIsSameYear({required DateTime dateTime}) {
    return _logs.where((log) => log.startTime.isSameYear(dateTime)).toList();
  }

  List<RoutineLogDto> whereLogsIsWithinRange({required DateTimeRange range}) {
    return _logs
        .where((log) =>
            log.startTime.isBetweenInclusive(from: range.start, to: range.end))
        .toList();
  }

  List<RoutineLogDto> whereLogsWithTemplateId({required String templateId}) {
    return _logs.where((log) => log.templateId == templateId).toList();
  }

  List<RoutineLogDto> whereLogsWithTemplateName(
      {required String templateName}) {
    return _logs.where((log) => log.name == templateName).toList();
  }

  List<RoutineLogDto> whereRoutineLogsBefore(
      {required String templateId, required DateTime date}) {
    return _logs
        .where((log) =>
            log.templateId == templateId && log.startTime.isBefore(date))
        .toList();
  }

  void clear() {
    _logs.clear();
    _exerciseLogsByExerciseId.clear();
  }

  /// Helper method to convert Supabase map to RoutineLogDto
  RoutineLogDto _convertMapToRoutineLogDto(Map<String, dynamic> item) {
    return RoutineLogDto.fromJson(json: Map<String, dynamic>.from(item));
  }
}
