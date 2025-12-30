import 'package:trainware/dtos/appsync/routine_log_dto.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';
import 'package:trainware/dtos/set_dtos/duration_set_dto.dart';
import 'package:trainware/dtos/set_dtos/reps_dto.dart';
import 'package:trainware/dtos/set_dtos/set_dto.dart';
import 'package:trainware/dtos/set_dtos/weight_and_reps_dto.dart';
import 'package:trainware/enums/exercise_type_enums.dart';
import 'package:trainware/extensions/duration_extension.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/utils/sets_utils.dart';

/// What kind of PB did we hit?
enum PersonalBestKind {
  heaviestWeight,
  mostReps,
  heaviestVolume,
  longestDuration,
}

/// Typed PB value (no parsing strings later).
class PersonalBest {
  final String exerciseName;
  final ExerciseType exerciseType;
  final PersonalBestKind kind;

  /// Only one of these is typically used depending on kind/type.
  final double? weightKg; // For heaviest weight / volume
  final int? reps; // For most reps / volume
  final Duration? duration; // For longest duration

  const PersonalBest({
    required this.exerciseName,
    required this.exerciseType,
    required this.kind,
    this.weightKg,
    this.reps,
    this.duration,
  });

  String get description {
    switch (kind) {
      case PersonalBestKind.heaviestWeight:
        return 'Heaviest Weight';
      case PersonalBestKind.mostReps:
        return 'Most Reps';
      case PersonalBestKind.heaviestVolume:
        return 'Heaviest Volume';
      case PersonalBestKind.longestDuration:
        return 'Longest Duration';
    }
  }
}

/// Main API: calculates PBs for the current workout, compared to historical logs.
/// PBs are computed on demand.
List<PersonalBest> calculatePersonalBests({
  required RoutineLogDto currentLog,
  required List<ExerciseLogDto> allHistoricalExerciseLogs,
}) {
  final pbs = <PersonalBest>[];

  for (final exerciseLog in currentLog.exerciseLogs) {
    final exerciseId = exerciseLog.exercise.id;
    final exerciseType = exerciseLog.exercise.type;
    final exerciseName = exerciseLog.exercise.name;

    if (exerciseType == ExerciseType.none) continue;

    // Historical logs for this exercise excluding current routine log
    final historicalLogs = allHistoricalExerciseLogs.where((log) {
      return log.exercise.id == exerciseId && log.routineLogId != currentLog.id;
    }).toList();

    if (historicalLogs.isEmpty) continue;

    // Only completed sets
    final historicalSets = historicalLogs
        .expand((log) => log.sets)
        .where(_isCompletedSet)
        .toList();

    final currentSets = exerciseLog.sets.where(_isCompletedSet).toList();

    if (historicalSets.isEmpty || currentSets.isEmpty) continue;

    switch (exerciseType) {
      case ExerciseType.weights:
        _checkWeightPBs(
          exerciseName: exerciseName,
          currentSets: currentSets,
          historicalSets: historicalSets,
          pbs: pbs,
        );
        break;

      case ExerciseType.bodyWeight:
        _checkBodyweightPBs(
          exerciseName: exerciseName,
          currentSets: currentSets,
          historicalSets: historicalSets,
          pbs: pbs,
        );
        break;

      case ExerciseType.duration:
        _checkDurationPBs(
          exerciseName: exerciseName,
          currentSets: currentSets,
          historicalSets: historicalSets,
          pbs: pbs,
        );
        break;

      case ExerciseType.none:
        break;
    }
  }

  return pbs;
}

bool _isCompletedSet(SetDto set) => set.isNotEmpty() && set.checked;

/// WEIGHTS PBs: heaviest weight, most reps, heaviest volume
void _checkWeightPBs({
  required String exerciseName,
  required List<SetDto> currentSets,
  required List<SetDto> historicalSets,
  required List<PersonalBest> pbs,
}) {
  final current = currentSets.whereType<WeightAndRepsSetDto>().toList();
  final historical = historicalSets.whereType<WeightAndRepsSetDto>().toList();
  if (current.isEmpty || historical.isEmpty) return;

  // 1) Heaviest weight
  final currentHeaviest = getHighestWeight(current);
  final historicalHeaviest = getHighestWeight(historical);

  if (currentHeaviest != null &&
      historicalHeaviest != null &&
      currentHeaviest.weight > historicalHeaviest.weight) {
    pbs.add(PersonalBest(
      exerciseName: exerciseName,
      exerciseType: ExerciseType.weights,
      kind: PersonalBestKind.heaviestWeight,
      weightKg: currentHeaviest.weight,
    ));
  }

  // 2) Most reps (for weight sets)
  final currentHighestReps = getHighestReps(current);
  final historicalHighestReps = getHighestReps(historical);

  if (currentHighestReps != null &&
      historicalHighestReps != null &&
      currentHighestReps.reps > historicalHighestReps.reps) {
    pbs.add(PersonalBest(
      exerciseName: exerciseName,
      exerciseType: ExerciseType.weights,
      kind: PersonalBestKind.mostReps,
      reps: currentHighestReps.reps,
    ));
  }

  // 3) Heaviest volume (weight x reps)
  final currentHeaviestVolume = getHeaviestVolume(current);
  final historicalHeaviestVolume = getHeaviestVolume(historical);

  if (currentHeaviestVolume != null &&
      historicalHeaviestVolume != null &&
      currentHeaviestVolume.volume() > historicalHeaviestVolume.volume()) {
    pbs.add(PersonalBest(
      exerciseName: exerciseName,
      exerciseType: ExerciseType.weights,
      kind: PersonalBestKind.heaviestVolume,
      weightKg: currentHeaviestVolume.weight,
      reps: currentHeaviestVolume.reps,
    ));
  }
}

/// BODYWEIGHT PBs: most reps
void _checkBodyweightPBs({
  required String exerciseName,
  required List<SetDto> currentSets,
  required List<SetDto> historicalSets,
  required List<PersonalBest> pbs,
}) {
  final current = currentSets.whereType<RepsSetDto>().toList();
  final historical = historicalSets.whereType<RepsSetDto>().toList();
  if (current.isEmpty || historical.isEmpty) return;

  final currentHighestReps = getHighestReps(current);
  final historicalHighestReps = getHighestReps(historical);

  if (currentHighestReps != null &&
      historicalHighestReps != null &&
      currentHighestReps.reps > historicalHighestReps.reps) {
    pbs.add(PersonalBest(
      exerciseName: exerciseName,
      exerciseType: ExerciseType.bodyWeight,
      kind: PersonalBestKind.mostReps,
      reps: currentHighestReps.reps,
    ));
  }
}

/// DURATION PBs: longest duration
void _checkDurationPBs({
  required String exerciseName,
  required List<SetDto> currentSets,
  required List<SetDto> historicalSets,
  required List<PersonalBest> pbs,
}) {
  final current = currentSets.whereType<DurationSetDto>().toList();
  final historical = historicalSets.whereType<DurationSetDto>().toList();
  if (current.isEmpty || historical.isEmpty) return;

  final currentLongest = getLongestDuration(current);
  final historicalLongest = getLongestDuration(historical);

  if (currentLongest != null &&
      historicalLongest != null &&
      currentLongest.duration > historicalLongest.duration) {
    pbs.add(PersonalBest(
      exerciseName: exerciseName,
      exerciseType: ExerciseType.duration,
      kind: PersonalBestKind.longestDuration,
      duration: currentLongest.duration,
    ));
  }
}

/// UI formatting: decision is based on exerciseType + PB kind only.
/// No string parsing. No heuristics.
String formatPersonalBestValue(
  PersonalBest pb, {
  required String weightUnitLabel, // e.g. "kg" or "lb"
}) {
  switch (pb.exerciseType) {
    case ExerciseType.weights:
      if (pb.kind == PersonalBestKind.mostReps) {
        return '${pb.reps ?? 0} reps';
      }

      if (pb.kind == PersonalBestKind.heaviestVolume) {
        final weightKg = pb.weightKg ?? 0;
        final reps = pb.reps ?? 0;
        final w = _formatWeightFromKg(weightKg, weightUnitLabel);
        return '$w × $reps';
      }

      // Heaviest weight
      final weightKg = pb.weightKg ?? 0;
      return _formatWeightFromKg(weightKg, weightUnitLabel);

    case ExerciseType.bodyWeight:
      return '${pb.reps ?? 0} reps';

    case ExerciseType.duration:
      return (pb.duration ?? Duration.zero).hmsDigital();

    case ExerciseType.none:
      return '';
  }
}

String _formatWeightFromKg(double weightKg, String weightUnitLabel) {
  // weightWithConversion(value: kg) should already exist in your project.
  final converted = weightWithConversion(value: weightKg);

  final formatted = converted.toStringAsFixed(
    converted.truncateToDouble() == converted ? 0 : 1,
  );

  return '$formatted $weightUnitLabel';
}
