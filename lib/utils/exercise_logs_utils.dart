// import removed
import 'package:trainware/dtos/appsync/routine_log_dto.dart';

import '../dtos/appsync/exercise_dto.dart';
import '../dtos/exercise_log_dto.dart';
import '../dtos/set_dtos/duration_set_dto.dart';
import '../dtos/set_dtos/reps_dto.dart';
import '../dtos/set_dtos/set_dto.dart';
import '../dtos/set_dtos/weight_and_reps_dto.dart';
import '../enums/exercise_type_enums.dart';
import '../enums/template_changes_type_message_enums.dart';

/// Entries for a specific set index across all exercise logs.
/// Returns (ExerciseLogDto, SetDto) pairs for logs that have that set.
/// setIndex is 0-based (0 = Set 1, 1 = Set 2, 2 = Set 3).
List<(ExerciseLogDto, SetDto)> getSetIndexEntries({
  required List<ExerciseLogDto> exerciseLogs,
  required int setIndex,
}) {
  final result = <(ExerciseLogDto, SetDto)>[];
  for (final log in exerciseLogs) {
    if (log.sets.length > setIndex) {
      result.add((log, log.sets[setIndex]));
    }
  }
  result.sort((a, b) => a.$1.createdAt.compareTo(b.$1.createdAt));
  return result;
}

/// Returns the maximum number of sets across all exercise logs.
int maxSetCountAcrossLogs({required List<ExerciseLogDto> exerciseLogs}) {
  if (exerciseLogs.isEmpty) return 0;
  return exerciseLogs
      .map((log) => log.sets.length)
      .reduce((a, b) => a > b ? a : b);
}

/// Top N distinct weights across all weight-based sets.
/// Returns heaviest first, descending.
List<double> getTopWeights({
  required List<ExerciseLogDto> exerciseLogs,
  int count = 3,
}) {
  final weights = <double>{};
  for (final log in exerciseLogs) {
    for (final set in log.sets) {
      if (set is WeightAndRepsSetDto && set.weight > 0) {
        weights.add(set.weight);
      }
    }
  }
  final sorted = weights.toList()..sort((a, b) => b.compareTo(a));
  return sorted.take(count).toList();
}

/// Entries for a specific weight across all exercise logs.
/// Returns (ExerciseLogDto, WeightAndRepsSetDto) pairs where set.weight matches.
List<(ExerciseLogDto, WeightAndRepsSetDto)> getEntriesForWeight({
  required List<ExerciseLogDto> exerciseLogs,
  required double weight,
}) {
  const epsilon = 1e-6;
  final result = <(ExerciseLogDto, WeightAndRepsSetDto)>[];
  for (final log in exerciseLogs) {
    for (final set in log.sets) {
      if (set is WeightAndRepsSetDto &&
          (set.weight - weight).abs() < epsilon) {
        result.add((log, set));
      }
    }
  }
  result.sort((a, b) => a.$1.createdAt.compareTo(b.$1.createdAt));
  return result;
}

/// One entry per session for a weight: the set with highest reps at that weight.
/// Returns (ExerciseLogDto, WeightAndRepsSetDto, int setIndex) - setIndex is 1-based.
List<(ExerciseLogDto, WeightAndRepsSetDto, int)> getEntriesForWeightMaxRepsPerSession({
  required List<ExerciseLogDto> exerciseLogs,
  required double weight,
}) {
  const epsilon = 1e-6;
  final result = <(ExerciseLogDto, WeightAndRepsSetDto, int)>[];
  for (final log in exerciseLogs) {
    WeightAndRepsSetDto? bestSet;
    int bestIndex = -1;
    for (var i = 0; i < log.sets.length; i++) {
      final set = log.sets[i];
      if (set is WeightAndRepsSetDto &&
          (set.weight - weight).abs() < epsilon &&
          (bestSet == null || set.reps > bestSet.reps)) {
        bestSet = set;
        bestIndex = i;
      }
    }
    if (bestSet != null && bestIndex >= 0) {
      result.add((log, bestSet, bestIndex + 1));
    }
  }
  result.sort((a, b) => a.$1.createdAt.compareTo(b.$1.createdAt));
  return result;
}

/// Highest value per [ExerciseLogDto]

WeightAndRepsSetDto heaviestWeightInSetForExerciseLog(
    {required ExerciseLogDto exerciseLog}) {
  final weightSets = exerciseLog.sets.whereType<WeightAndRepsSetDto>().toList();

  if (weightSets.isEmpty) {
    return WeightAndRepsSetDto.defaultSet();
  }

  return weightSets.reduce((currentHeaviest, nextSet) =>
      nextSet.weight > currentHeaviest.weight ? nextSet : currentHeaviest);
}

Duration longestDurationForExerciseLog({required ExerciseLogDto exerciseLog}) {
  final durationSets = exerciseLog.sets.whereType<DurationSetDto>();

  if (durationSets.isEmpty) {
    return Duration.zero;
  }

  return durationSets
      .map((set) => set.duration)
      .reduce((max, duration) => duration > max ? duration : max);
}

Duration totalDurationExerciseLog({required ExerciseLogDto exerciseLog}) {
  return exerciseLog.sets.whereType<DurationSetDto>().fold<Duration>(
        Duration.zero,
        (total, set) => total + set.duration,
      );
}

int totalRepsForExerciseLog({required ExerciseLogDto exerciseLog}) {
  final exerciseType = exerciseLog.exercise.type;

  if (exerciseType == ExerciseType.bodyWeight) {
    return exerciseLog.sets
        .whereType<RepsSetDto>()
        .fold(0, (total, set) => total + set.reps);
  } else if (exerciseType == ExerciseType.weights) {
    return exerciseLog.sets
        .whereType<WeightAndRepsSetDto>()
        .fold(0, (total, set) => total + set.reps);
  }

  return 0;
}

int highestRepsForExerciseLog({required ExerciseLogDto exerciseLog}) {
  final exerciseType = exerciseLog.exercise.type;

  if (exerciseType == ExerciseType.bodyWeight) {
    final repsSets = exerciseLog.sets.whereType<RepsSetDto>();
    if (repsSets.isEmpty) return 0;
    return repsSets
        .map((set) => set.reps)
        .reduce((curr, next) => curr > next ? curr : next);
  } else if (exerciseType == ExerciseType.weights) {
    final weightSets = exerciseLog.sets.whereType<WeightAndRepsSetDto>();
    if (weightSets.isEmpty) return 0;
    return weightSets
        .map((set) => set.reps)
        .reduce((curr, next) => curr > next ? curr : next);
  }

  return 0;
}

double heaviestVolumeForExerciseLog({required ExerciseLogDto exerciseLog}) {
  final weightSets = exerciseLog.sets.whereType<WeightAndRepsSetDto>();

  if (weightSets.isEmpty) return 0.0;

  return weightSets
      .map((set) => set.volume())
      .reduce((prev, element) => element > prev ? element : prev);
}

WeightAndRepsSetDto heaviestSetVolumeForExerciseLog(
    {required ExerciseLogDto exerciseLog}) {
  final weightSets = exerciseLog.sets.whereType<WeightAndRepsSetDto>();

  if (weightSets.isEmpty) {
    return SetDto.newType(type: ExerciseType.weights) as WeightAndRepsSetDto;
  }

  return weightSets.reduce((heaviestSet, currentSet) =>
      currentSet.volume() > heaviestSet.volume() ? currentSet : heaviestSet);
}

/// Highest value across all [ExerciseDto]

(String?, SetDto) heaviestSetVolume(
    {required List<ExerciseLogDto> exerciseLogs}) {
  if (exerciseLogs.isEmpty) {
    return (null, SetDto.newType(type: ExerciseType.weights));
  }

  String? logId;
  SetDto? heaviestSet;
  double heaviestVolume = 0.0;

  for (final log in exerciseLogs) {
    final currentSet = heaviestSetVolumeForExerciseLog(exerciseLog: log);
    final currentVolume = currentSet.volume();
    if (currentVolume > heaviestVolume) {
      logId = log.routineLogId;
      heaviestVolume = currentVolume;
      heaviestSet = currentSet;
    }
  }

  return heaviestSet != null
      ? (logId, heaviestSet)
      : (null, SetDto.newType(type: ExerciseType.weights));
}

(String?, double) heaviestWeight({required List<ExerciseLogDto> exerciseLogs}) {
  String? logId;
  double heaviestWeight = 0.0;

  for (final log in exerciseLogs) {
    final heaviestSet = heaviestWeightInSetForExerciseLog(exerciseLog: log);
    final weight = heaviestSet.weight;
    if (weight > heaviestWeight) {
      logId = log.routineLogId;
      heaviestWeight = weight;
    }
  }

  return (logId, heaviestWeight);
}

(String?, int) mostRepsInSet({required List<ExerciseLogDto> exerciseLogs}) {
  String? logId;
  int highestReps = 0;

  for (final log in exerciseLogs) {
    final exerciseType = log.exercise.type;
    int logHighestReps = 0;

    if (exerciseType == ExerciseType.bodyWeight) {
      final repsSets = log.sets.whereType<RepsSetDto>();
      if (repsSets.isNotEmpty) {
        logHighestReps = repsSets
            .map((set) => set.reps)
            .reduce((curr, next) => curr > next ? curr : next);
      }
    } else if (exerciseType == ExerciseType.weights) {
      final weightSets = log.sets.whereType<WeightAndRepsSetDto>();
      if (weightSets.isNotEmpty) {
        logHighestReps = weightSets
            .map((set) => set.reps)
            .reduce((curr, next) => curr > next ? curr : next);
      }
    }

    if (logHighestReps > highestReps) {
      logId = log.routineLogId;
      highestReps = logHighestReps;
    }
  }

  return (logId, highestReps);
}

(String?, int) mostRepsInSession({required List<ExerciseLogDto> exerciseLogs}) {
  String? logId;
  int mostReps = 0;

  for (final log in exerciseLogs) {
    final totalReps = totalRepsForExerciseLog(exerciseLog: log);
    if (totalReps > mostReps) {
      logId = log.routineLogId;
      mostReps = totalReps;
    }
  }

  return (logId, mostReps);
}

(String?, Duration) longestDuration(
    {required List<ExerciseLogDto> exerciseLogs}) {
  Duration longestDuration = Duration.zero;
  String? logId;

  for (final log in exerciseLogs) {
    final duration = longestDurationForExerciseLog(exerciseLog: log);
    if (duration > longestDuration) {
      logId = log.routineLogId;
      longestDuration = duration;
    }
  }

  return (logId, longestDuration);
}

// Personal bests removed from project

TemplateChange? hasDifferentExerciseLogsLength(
    {required List<ExerciseLogDto> exerciseLogs1,
    required List<ExerciseLogDto> exerciseLogs2}) {
  return exerciseLogs2.length != exerciseLogs1.length
      ? TemplateChange.exerciseLogLength
      : null;
}

TemplateChange? hasReOrderedExercises(
    {required List<ExerciseLogDto> exerciseLogs1,
    required List<ExerciseLogDto> exerciseLogs2}) {
  final length = exerciseLogs1.length > exerciseLogs2.length
      ? exerciseLogs2.length
      : exerciseLogs1.length;
  for (int i = 0; i < length; i++) {
    if (exerciseLogs1[i].exercise.id != exerciseLogs2[i].exercise.id) {
      return TemplateChange.exerciseOrder; // Re-orderedList
    }
  }
  return null;
}

TemplateChange? hasDifferentSetsLength(
    {required List<ExerciseLogDto> exerciseLogs1,
    required List<ExerciseLogDto> exerciseLogs2}) {
  final exerciseLog1Sets = exerciseLogs1.expand((logs) => logs.sets);
  final exerciseLog2Sets = exerciseLogs2.expand((logs) => logs.sets);

  return exerciseLog1Sets.length != exerciseLog2Sets.length
      ? TemplateChange.setsLength
      : null;
}

TemplateChange? hasExercisesChanged({
  required List<ExerciseLogDto> exerciseLogs1,
  required List<ExerciseLogDto> exerciseLogs2,
}) {
  Set<String> exerciseIds1 = exerciseLogs1.map((p) => p.exercise.id).toSet();
  Set<String> exerciseIds2 = exerciseLogs2.map((p) => p.exercise.id).toSet();

  int changes = exerciseIds1.difference(exerciseIds2).length;

  return changes > 0 ? TemplateChange.exerciseLogChange : null;
}

TemplateChange? hasSuperSetIdChanged({
  required List<ExerciseLogDto> exerciseLogs1,
  required List<ExerciseLogDto> exerciseLogs2,
}) {
  Set<String> superSetIds1 = exerciseLogs1
      .map((p) => p.superSetId)
      .where((superSetId) => superSetId.isNotEmpty)
      .toSet();
  Set<String> superSetIds2 = exerciseLogs2
      .map((p) => p.superSetId)
      .where((superSetId) => superSetId.isNotEmpty)
      .toSet();

  final changes = superSetIds2.difference(superSetIds1).length;

  return changes > 0 ? TemplateChange.supersetId : null;
}

TemplateChange? hasCheckedSetsChanged(
    {required List<ExerciseLogDto> exerciseLogs1,
    required List<ExerciseLogDto> exerciseLogs2}) {
  final exerciseLog1CompletedSets = exerciseLogs1
      .expand((log) => log.sets)
      .where((set) => set.checked)
      .toList();
  final exerciseLog2CompletedSets = exerciseLogs2
      .expand((log) => log.sets)
      .where((set) => set.checked)
      .toList();

  if (exerciseLog1CompletedSets.length != exerciseLog2CompletedSets.length) {
    return TemplateChange.checkedSets;
  }

  return null;
}

TemplateChange? hasSetValueChanged({
  required List<ExerciseLogDto> exerciseLogs1,
  required List<ExerciseLogDto> exerciseLogs2,
}) {
  final exerciseLog1Volume =
      exerciseLogs1.expand((logs) => logs.sets).fold(0.0, (previousValue, set) {
    return switch (set.type) {
      ExerciseType.weights =>
        previousValue + (set as WeightAndRepsSetDto).volume(),
      ExerciseType.bodyWeight => previousValue + (set as RepsSetDto).reps,
      ExerciseType.duration =>
        previousValue + (set as DurationSetDto).duration.inMilliseconds,
      ExerciseType.none => previousValue,
    };
  });

  final exerciseLog2Volume =
      exerciseLogs2.expand((logs) => logs.sets).fold(0.0, (previousValue, set) {
    return switch (set.type) {
      ExerciseType.weights =>
        previousValue + (set as WeightAndRepsSetDto).volume(),
      ExerciseType.bodyWeight => previousValue + (set as RepsSetDto).reps,
      ExerciseType.duration =>
        previousValue + (set as DurationSetDto).duration.inMilliseconds,
      ExerciseType.none => previousValue,
    };
  });

  return exerciseLog1Volume != exerciseLog2Volume
      ? TemplateChange.setValue
      : null;
}

/// Heuristic to detect if a user is consistently hitting the same weight
/// and reps for a weights-based exercise across recent sessions.
///
/// We look at up to [recentLogs] (most recent first) and:
/// - Group by routineLogId to ensure we count only one set per session
/// - Extract the last non-empty set from each distinct session
/// - Require at least [minSessions] distinct sessions with valid sets
/// - Consider it "stalled" if all (weight, reps) pairs are identical.
/// Returns the count of stalled sessions if stalled, or 0 if not stalled.
/// A session is considered stalled if all sessions have the same weight and reps.
int getStalledSessionsCountAtSameWeightAndReps({
  required List<ExerciseLogDto> recentLogs,
  int minSessions = 5,
}) {
  if (recentLogs.isEmpty) return 0;

  // Group by routineLogId to ensure we count only one set per session
  // even if the same exercise appears multiple times in a session
  final sessionsByRoutineLogId = <String?, ExerciseLogDto>{};
  for (final log in recentLogs) {
    final routineLogId = log.routineLogId;
    // If we haven't seen this session yet, or if this is a more recent entry
    // (though recentLogs should already be sorted), keep the first one we encounter
    if (!sessionsByRoutineLogId.containsKey(routineLogId)) {
      sessionsByRoutineLogId[routineLogId] = log;
    }
  }

  final samples = <(double weight, int reps)>[];

  // Process each distinct session
  for (final log in sessionsByRoutineLogId.values) {
    final weightSets = log.sets
        .where((s) => s.type == ExerciseType.weights)
        .map((s) => s as WeightAndRepsSetDto)
        .where((s) => s.weight > 0 && s.reps > 0)
        .toList();

    if (weightSets.isEmpty) continue;

    // Use the last filled set in this session as the "top set"
    final last = weightSets.last;
    samples.add((last.weight, last.reps));
  }

  if (samples.length < minSessions) return 0;

  final (firstWeight, firstReps) = samples.first;
  final isStalled = samples
      .every((sample) => sample.$1 == firstWeight && sample.$2 == firstReps);

  return isStalled ? samples.length : 0;
}

bool isStalledAtSameWeightAndReps({
  required List<ExerciseLogDto> recentLogs,
  int minSessions = 5,
}) {
  return getStalledSessionsCountAtSameWeightAndReps(
        recentLogs: recentLogs,
        minSessions: minSessions,
      ) >
      0;
}

/// Returns the count of stalled sessions if stalled, or 0 if not stalled.
/// A session is considered stalled if all sessions have the same reps.
int getStalledSessionsCountAtSameReps({
  required List<ExerciseLogDto> recentLogs,
  int minSessions = 5,
}) {
  if (recentLogs.isEmpty) return 0;

  // Group by routineLogId to ensure we count only one set per session
  // even if the same exercise appears multiple times in a session
  final sessionsByRoutineLogId = <String?, ExerciseLogDto>{};
  for (final log in recentLogs) {
    final routineLogId = log.routineLogId;
    // If we haven't seen this session yet, or if this is a more recent entry
    // (though recentLogs should already be sorted), keep the first one we encounter
    if (!sessionsByRoutineLogId.containsKey(routineLogId)) {
      sessionsByRoutineLogId[routineLogId] = log;
    }
  }

  final samples = <int>[];

  // Process each distinct session
  for (final log in sessionsByRoutineLogId.values) {
    final repsSets = log.sets
        .where((s) => s.type == ExerciseType.bodyWeight)
        .map((s) => s as RepsSetDto)
        .where((s) => s.reps > 0)
        .toList();

    if (repsSets.isEmpty) continue;

    // Use the last filled set in this session as the "top set"
    final last = repsSets.last;
    samples.add(last.reps);
  }

  if (samples.length < minSessions) return 0;

  final firstReps = samples.first;
  final isStalled = samples.every((reps) => reps == firstReps);

  return isStalled ? samples.length : 0;
}

bool isStalledAtSameReps({
  required List<ExerciseLogDto> recentLogs,
  int minSessions = 5,
}) {
  return getStalledSessionsCountAtSameReps(
        recentLogs: recentLogs,
        minSessions: minSessions,
      ) >
      0;
}

bool withWeightsOnly({required ExerciseType type}) {
  return type == ExerciseType.weights;
}

bool withReps({required ExerciseType type}) {
  return type == ExerciseType.weights || type == ExerciseType.bodyWeight;
}

bool withRepsOnly({required ExerciseType type}) {
  return type == ExerciseType.bodyWeight;
}

bool withDurationOnly({required ExerciseType type}) {
  return type == ExerciseType.duration;
}

/// Time periods for filtering exercise logs.
enum ExerciseLogTimePeriod {
  last30Days('Last 30 days'),
  quarter('Quarter'),
  lastYear('Last year');

  const ExerciseLogTimePeriod(this.label);
  final String label;
}

/// Returns logs whose createdAt is within the given time period.
List<ExerciseLogDto> filterExerciseLogsByTimePeriod({
  required List<ExerciseLogDto> exerciseLogs,
  required ExerciseLogTimePeriod period,
}) {
  final now = DateTime.now();
  final DateTime cutoff;
  switch (period) {
    case ExerciseLogTimePeriod.last30Days:
      cutoff = now.subtract(const Duration(days: 30));
      break;
    case ExerciseLogTimePeriod.quarter:
      cutoff = now.subtract(const Duration(days: 90));
      break;
    case ExerciseLogTimePeriod.lastYear:
      cutoff = now.subtract(const Duration(days: 365));
      break;
  }
  return exerciseLogs
      .where((log) => !log.createdAt.isBefore(cutoff))
      .toList();
}

List<ExerciseLogDto> loggedExercises(
    {required List<ExerciseLogDto> exerciseLogs}) {
  return exerciseLogs.where((exerciseLog) {
    final completedSets =
        exerciseLog.sets.where((set) => set.isNotEmpty() && set.checked);
    return completedSets.isNotEmpty;
  }).map((log) {
    final sets =
        log.sets.where((set) => set.isNotEmpty() && set.checked).toList();
    return log.copyWith(sets: sets);
  }).toList();
}

RoutineLogDto routineWithLoggedExercises({required RoutineLogDto log}) {
  final loggedExerciseLogs = log.exerciseLogs.where((exerciseLog) {
    final completedSets =
        exerciseLog.sets.where((set) => set.isNotEmpty() && set.checked);
    return completedSets.isNotEmpty;
  }).map((log) {
    final sets =
        log.sets.where((set) => set.isNotEmpty() && set.checked).toList();
    return log.copyWith(sets: sets);
  }).toList();

  return log.copyWith(exerciseLogs: loggedExerciseLogs);
}

// --- Progression / compare helpers ---

double totalSessionVolumeForExerciseLog({required ExerciseLogDto exerciseLog}) {
  final type = exerciseLog.exercise.type;
  if (type == ExerciseType.weights) {
    return exerciseLog.sets
        .whereType<WeightAndRepsSetDto>()
        .where((s) => s.weight > 0 && s.reps > 0 && s.checked)
        .fold<double>(0.0, (sum, s) => sum + s.volume());
  }
  if (type == ExerciseType.bodyWeight) {
    return exerciseLog.sets
        .whereType<RepsSetDto>()
        .where((s) => s.reps > 0 && s.checked)
        .fold<double>(0.0, (sum, s) => sum + s.reps);
  }
  if (type == ExerciseType.duration) {
    return exerciseLog.sets
        .whereType<DurationSetDto>()
        .where((s) => s.duration.inMilliseconds > 0 && s.checked)
        .fold<double>(0.0, (sum, s) => sum + s.duration.inMilliseconds);
  }
  return 0.0;
}

enum ProgressionTrend { improving, stable, regressing }

List<ExerciseLogDto> _distinctSessionsByRoutineLogId(List<ExerciseLogDto> logs) {
  final byId = <String?, ExerciseLogDto>{};
  for (final log in logs) {
    if (!byId.containsKey(log.routineLogId)) byId[log.routineLogId] = log;
  }
  return byId.values.toList()..sort((a, b) => a.createdAt.compareTo(b.createdAt));
}

double _avgHeaviestWeightPerSession(List<ExerciseLogDto> logs) {
  if (logs.isEmpty) return 0.0;
  double sum = 0.0;
  for (final log in logs) {
    final set = heaviestWeightInSetForExerciseLog(exerciseLog: log);
    if (set.weight > 0) sum += set.weight;
  }
  return sum / logs.length;
}

ProgressionTrend getProgressionTrendForWeightLogs(List<ExerciseLogDto> sortedLogs, {int recentCount = 4}) {
  if (sortedLogs.length < 2 || recentCount < 1) return ProgressionTrend.stable;
  final distinct = _distinctSessionsByRoutineLogId(sortedLogs);
  if (distinct.length < 2) return ProgressionTrend.stable;
  final recent = distinct.reversed.take(recentCount).toList();
  final previous = distinct.reversed.skip(recentCount).take(recentCount).toList();
  if (previous.isEmpty) return ProgressionTrend.stable;
  double recentAvg = _avgHeaviestWeightPerSession(recent);
  double previousAvg = _avgHeaviestWeightPerSession(previous);
  if (recentAvg > previousAvg * 1.02) return ProgressionTrend.improving;
  if (recentAvg < previousAvg * 0.98) return ProgressionTrend.regressing;
  return ProgressionTrend.stable;
}

ProgressionTrend getProgressionTrendForVolumeLogs(List<ExerciseLogDto> sortedLogs, {int recentCount = 4}) {
  if (sortedLogs.length < 2 || recentCount < 1) return ProgressionTrend.stable;
  final distinct = _distinctSessionsByRoutineLogId(sortedLogs);
  if (distinct.length < 2) return ProgressionTrend.stable;
  final recent = distinct.reversed.take(recentCount).toList();
  final previous = distinct.reversed.skip(recentCount).take(recentCount).toList();
  if (previous.isEmpty) return ProgressionTrend.stable;
  double recentAvg = recent.fold<double>(0.0, (s, log) => s + totalSessionVolumeForExerciseLog(exerciseLog: log)) / recent.length;
  double previousAvg = previous.fold<double>(0.0, (s, log) => s + totalSessionVolumeForExerciseLog(exerciseLog: log)) / previous.length;
  if (recentAvg > previousAvg * 1.05) return ProgressionTrend.improving;
  if (recentAvg < previousAvg * 0.95) return ProgressionTrend.regressing;
  return ProgressionTrend.stable;
}

ProgressionTrend getProgressionTrendForRepsLogs(List<ExerciseLogDto> sortedLogs, {int recentCount = 4}) {
  if (sortedLogs.length < 2 || recentCount < 1) return ProgressionTrend.stable;
  final distinct = _distinctSessionsByRoutineLogId(sortedLogs);
  if (distinct.length < 2) return ProgressionTrend.stable;
  final recent = distinct.reversed.take(recentCount).toList();
  final previous = distinct.reversed.skip(recentCount).take(recentCount).toList();
  if (previous.isEmpty) return ProgressionTrend.stable;
  double recentAvg = recent.fold<double>(0.0, (s, log) => s + totalRepsForExerciseLog(exerciseLog: log)) / recent.length;
  double previousAvg = previous.fold<double>(0.0, (s, log) => s + totalRepsForExerciseLog(exerciseLog: log)) / previous.length;
  if (recentAvg > previousAvg * 1.05) return ProgressionTrend.improving;
  if (recentAvg < previousAvg * 0.95) return ProgressionTrend.regressing;
  return ProgressionTrend.stable;
}

ProgressionTrend getProgressionTrendForDurationLogs(List<ExerciseLogDto> sortedLogs, {int recentCount = 4}) {
  if (sortedLogs.length < 2 || recentCount < 1) return ProgressionTrend.stable;
  final distinct = _distinctSessionsByRoutineLogId(sortedLogs);
  if (distinct.length < 2) return ProgressionTrend.stable;
  final recent = distinct.reversed.take(recentCount).toList();
  final previous = distinct.reversed.skip(recentCount).take(recentCount).toList();
  if (previous.isEmpty) return ProgressionTrend.stable;
  double recentAvg = recent.fold<double>(0.0, (s, log) => s + totalDurationExerciseLog(exerciseLog: log).inMilliseconds) / recent.length;
  double previousAvg = previous.fold<double>(0.0, (s, log) => s + totalDurationExerciseLog(exerciseLog: log).inMilliseconds) / previous.length;
  if (recentAvg > previousAvg * 1.05) return ProgressionTrend.improving;
  if (recentAvg < previousAvg * 0.95) return ProgressionTrend.regressing;
  return ProgressionTrend.stable;
}

(double weight, List<int> reps)? repsAtSameWeightSummary(List<ExerciseLogDto> sortedLogs, {int minSessionsAtWeight = 2}) {
  if (sortedLogs.isEmpty) return null;
  final distinct = _distinctSessionsByRoutineLogId(sortedLogs);
  if (distinct.length < minSessionsAtWeight) return null;
  final weightSetsByLog = <ExerciseLogDto, WeightAndRepsSetDto>{};
  for (final log in distinct) {
    final sets = log.sets.whereType<WeightAndRepsSetDto>().where((s) => s.weight > 0 && s.reps > 0 && s.checked).toList();
    if (sets.isEmpty) continue;
    weightSetsByLog[log] = sets.reduce((a, b) => a.weight >= b.weight ? a : b);
  }
  if (weightSetsByLog.length < minSessionsAtWeight) return null;
  final weights = weightSetsByLog.values.map((s) => s.weight).toList();
  double bucketWeight = weights.first;
  int maxCount = 0;
  for (final w in weights) {
    final count = weights.where((x) => (x - w).abs() < 1.0).length;
    if (count > maxCount) { maxCount = count; bucketWeight = w; }
  }
  if (maxCount < minSessionsAtWeight) return null;
  final sessionsWithWeight = distinct.where((log) {
    final s = weightSetsByLog[log];
    return s != null && (s.weight - bucketWeight).abs() < 1.0;
  }).toList();
  sessionsWithWeight.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  return (bucketWeight, sessionsWithWeight.map((log) => weightSetsByLog[log]!.reps).toList());
}
