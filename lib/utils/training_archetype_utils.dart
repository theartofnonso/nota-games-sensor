import 'package:tracker_app/dtos/appsync/routine_log_dto.dart';
import 'package:tracker_app/enums/muscle_group_enums.dart';
import 'package:tracker_app/enums/training_archetype.dart';
import 'package:tracker_app/extensions/datetime/datetime_extension.dart';

import 'date_utils.dart';

TrainingFrequencyArchetype trainingFrequencyArchetype({required int avgSessions}) {
  if (avgSessions <= 2) return TrainingFrequencyArchetype.rarelyTrains;
  if (avgSessions <= 4) return TrainingFrequencyArchetype.oftenTrains;
  return TrainingFrequencyArchetype.alwaysTrains;
}

TrainingDurationArchetype trainingDurationArchetype({required Duration avgDuration}) {
  final minutes = avgDuration.inMinutes;
  if (minutes < 30) return TrainingDurationArchetype.shortSessions;
  if (minutes < 60) return TrainingDurationArchetype.standardSessions;
  return TrainingDurationArchetype.extendedSessions;
}

MuscleFocusArchetype muscleFocusArchetype({required List<RoutineLogDto> logs}) {
  int upperSets = 0;
  int lowerSets = 0;

  for (final log in logs) {
    for (final exerciseLog in log.exerciseLogs) {
      final primaryMuscleGroup = exerciseLog.exercise.primaryMuscleGroup;
      final sets = exerciseLog.sets.length;
      if (MuscleGroup.upper.contains(primaryMuscleGroup)) {
        upperSets += sets;
      } else if (MuscleGroup.lower.contains(primaryMuscleGroup)) {
        lowerSets += sets;
      }
    }
  }

  final total = upperSets + lowerSets;
  if (total == 0) return MuscleFocusArchetype.fullBodyBalanced; // fallback

  final upperRatio = upperSets / total;
  final lowerRatio = lowerSets / total;

  if (upperRatio >= 0.60) return MuscleFocusArchetype.upperBodyFocus;
  if (lowerRatio >= 0.60) return MuscleFocusArchetype.lowerBodyFocus;
  return MuscleFocusArchetype.fullBodyBalanced;
}

/// Returns both archetypes for the supplied [logs] (any order).
List<TrainingArchetype> classifyTrainingArchetypes({
  required List<RoutineLogDto> logs,
}) {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------
  /// Returns a rounded‐up mean for any list of ints.
  int safeAverage(List<int> values) => values.isEmpty ? 0 : (values.reduce((a, b) => a + b) / values.length).round();

  // ---------------------------------------------------------------------------
  // 1. Collect the last 13 calendar weeks
  // ---------------------------------------------------------------------------
  final dateRange = lastQuarterDateTimeRange();
  final weeksInLastQuarter =
      generateWeeksInRange(range: dateRange).toList(); // chronological order

  // ---------------------------------------------------------------------------
  // 2. Compute weekly session counts & store every single workout duration
  // ---------------------------------------------------------------------------
  final List<int> sessionsPerWeek = <int>[];
  final List<int> allDurations = <int>[]; // in minutes

  for (final week in weeksInLastQuarter) {
    final weekLogs = logs.where(
      (log) => log.createdAt.isBetweenInclusive(from: week.start, to: week.end),
    );

    sessionsPerWeek.add(weekLogs.length);
    allDurations.addAll(weekLogs.map((log) => log.duration().inMinutes));
  }

  // ---------------------------------------------------------------------------
  // 3. Weekly-average archetypes (safe even when the lists are empty)
  // ---------------------------------------------------------------------------
  final trainingFrequencyArch = trainingFrequencyArchetype(avgSessions: safeAverage(sessionsPerWeek));

  final trainingDurationArch = trainingDurationArchetype(
    avgDuration: Duration(minutes: safeAverage(allDurations)),
  );

  // ---------------------------------------------------------------------------
  // 4. Muscle-focus archetype
  // ---------------------------------------------------------------------------
  final muscleFocusArch = muscleFocusArchetype(logs: logs);

  // ---------------------------------------------------------------------------
  // 5. Return the archetype bundle
  // ---------------------------------------------------------------------------
  return [
    trainingFrequencyArch,
    trainingDurationArch,
    muscleFocusArch,
  ];
}
