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

/// Represents a personal best achievement in a workout
class PersonalBest {
  final String exerciseName;
  final ExerciseType exerciseType;
  final String description;
  final String value;

  const PersonalBest({
    required this.exerciseName,
    required this.exerciseType,
    required this.description,
    required this.value,
  });
}

/// Calculate personal bests achieved in the current workout compared to historical data
List<PersonalBest> calculatePersonalBests({
  required RoutineLogDto currentLog,
  required List<ExerciseLogDto> allHistoricalExerciseLogs,
}) {
  final pbs = <PersonalBest>[];

  for (final exerciseLog in currentLog.exerciseLogs) {
    final exerciseId = exerciseLog.exercise.id;
    final exerciseType = exerciseLog.exercise.type;
    final exerciseName = exerciseLog.exercise.name;

    // Get all historical logs for this exercise (excluding current log)
    final historicalLogs = allHistoricalExerciseLogs
        .where((log) =>
            log.exercise.id == exerciseId && log.routineLogId != currentLog.id)
        .toList();

    if (historicalLogs.isEmpty) {
      // No historical data, skip
      continue;
    }

    // Collect all historical sets for this exercise
    final allHistoricalSets = historicalLogs
        .expand((log) => log.sets)
        .where((set) => set.isNotEmpty() && set.checked)
        .toList();

    if (allHistoricalSets.isEmpty) {
      continue;
    }

    // Get current workout sets (only checked/completed sets)
    final currentSets = exerciseLog.sets
        .where((set) => set.isNotEmpty() && set.checked)
        .toList();

    if (currentSets.isEmpty) {
      continue;
    }

    // Check for PBs based on exercise type
    switch (exerciseType) {
      case ExerciseType.weights:
        _checkWeightPBs(
          exerciseName: exerciseName,
          currentSets: currentSets,
          historicalSets: allHistoricalSets,
          pbs: pbs,
        );
        break;
      case ExerciseType.bodyWeight:
        _checkRepsPBs(
          exerciseName: exerciseName,
          currentSets: currentSets,
          historicalSets: allHistoricalSets,
          pbs: pbs,
        );
        break;
      case ExerciseType.duration:
        _checkDurationPBs(
          exerciseName: exerciseName,
          currentSets: currentSets,
          historicalSets: allHistoricalSets,
          pbs: pbs,
        );
        break;
      case ExerciseType.none:
        // Skip PB evaluation until a type is selected
        break;
    }
  }

  return pbs;
}

void _checkWeightPBs({
  required String exerciseName,
  required List<SetDto> currentSets,
  required List<SetDto> historicalSets,
  required List<PersonalBest> pbs,
}) {
  final currentWeightSets =
      currentSets.whereType<WeightAndRepsSetDto>().toList();
  final historicalWeightSets =
      historicalSets.whereType<WeightAndRepsSetDto>().toList();

  if (currentWeightSets.isEmpty || historicalWeightSets.isEmpty) return;

  // Check for heaviest weight PB
  final currentHeaviest = getHighestWeight(currentWeightSets);
  final historicalHeaviest = getHighestWeight(historicalWeightSets);

  if (currentHeaviest != null &&
      historicalHeaviest != null &&
      currentHeaviest.weight > historicalHeaviest.weight) {
    pbs.add(PersonalBest(
      exerciseName: exerciseName,
      exerciseType: ExerciseType.weights,
      description: 'Heaviest Weight',
      value: '${currentHeaviest.weight}${weightUnit()}',
    ));
  }

  // Check for most reps PB
  final currentHighestReps = getHighestReps(currentWeightSets);
  final historicalHighestReps = getHighestReps(historicalWeightSets);

  if (currentHighestReps != null &&
      historicalHighestReps != null &&
      currentHighestReps.reps > historicalHighestReps.reps) {
    pbs.add(PersonalBest(
      exerciseName: exerciseName,
      exerciseType: ExerciseType.weights,
      description: 'Most Reps',
      value: '${currentHighestReps.reps} reps',
    ));
  }

  // Check for heaviest volume PB
  final currentHeaviestVolume = getHeaviestVolume(currentWeightSets);
  final historicalHeaviestVolume = getHeaviestVolume(historicalWeightSets);

  if (currentHeaviestVolume != null &&
      historicalHeaviestVolume != null &&
      currentHeaviestVolume.volume() > historicalHeaviestVolume.volume()) {
    pbs.add(PersonalBest(
      exerciseName: exerciseName,
      exerciseType: ExerciseType.weights,
      description: 'Heaviest Volume',
      value:
          '${currentHeaviestVolume.weight}${weightUnit()} × ${currentHeaviestVolume.reps}',
    ));
  }
}

void _checkRepsPBs({
  required String exerciseName,
  required List<SetDto> currentSets,
  required List<SetDto> historicalSets,
  required List<PersonalBest> pbs,
}) {
  final currentRepsSets = currentSets.whereType<RepsSetDto>().toList();
  final historicalRepsSets = historicalSets.whereType<RepsSetDto>().toList();

  if (currentRepsSets.isEmpty || historicalRepsSets.isEmpty) return;

  // Check for most reps PB
  final currentHighestReps = getHighestReps(currentRepsSets);
  final historicalHighestReps = getHighestReps(historicalRepsSets);

  if (currentHighestReps != null &&
      historicalHighestReps != null &&
      currentHighestReps.reps > historicalHighestReps.reps) {
    pbs.add(PersonalBest(
      exerciseName: exerciseName,
      exerciseType: ExerciseType.bodyWeight,
      description: 'Most Reps',
      value: '${currentHighestReps.reps} reps',
    ));
  }
}

void _checkDurationPBs({
  required String exerciseName,
  required List<SetDto> currentSets,
  required List<SetDto> historicalSets,
  required List<PersonalBest> pbs,
}) {
  final currentDurationSets = currentSets.whereType<DurationSetDto>().toList();
  final historicalDurationSets =
      historicalSets.whereType<DurationSetDto>().toList();

  if (currentDurationSets.isEmpty || historicalDurationSets.isEmpty) return;

  // Check for longest duration PB
  final currentLongest = getLongestDuration(currentDurationSets);
  final historicalLongest = getLongestDuration(historicalDurationSets);

  if (currentLongest != null &&
      historicalLongest != null &&
      currentLongest.duration > historicalLongest.duration) {
    pbs.add(PersonalBest(
      exerciseName: exerciseName,
      exerciseType: ExerciseType.duration,
      description: 'Longest Duration',
      value: currentLongest.duration.hmsDigital(),
    ));
  }
}
