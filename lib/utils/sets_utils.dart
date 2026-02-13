import 'package:collection/collection.dart';
import 'package:trainware/dtos/set_dtos/duration_set_dto.dart';

import '../dtos/exercise_log_dto.dart';
import '../dtos/set_dtos/reps_dto.dart';
import '../dtos/set_dtos/set_dto.dart';
import '../dtos/set_dtos/weight_and_reps_dto.dart';
import '../enums/exercise_type_enums.dart';

List<SetDto> personalBestSets({required List<SetDto> sets}) {
  final groupedByReps =
      groupBy(sets, (set) => (set as WeightAndRepsSetDto).reps);

  final setsWithHeaviestWeight = <SetDto>[];

  for (var group in groupedByReps.entries) {
    final weights =
        group.value.map((set) => (set as WeightAndRepsSetDto).weight);
    final heaviestWeight = weights.max;
    setsWithHeaviestWeight.add(WeightAndRepsSetDto(
        weight: heaviestWeight,
        reps: group.key,
        checked: false,
        dateTime: DateTime.now()));
  }

  // Sort by reps
  setsWithHeaviestWeight.sort((a, b) => (a as WeightAndRepsSetDto)
      .reps
      .compareTo((b as WeightAndRepsSetDto).reps));

  return setsWithHeaviestWeight;
}

List<String> generateSetSummaries(ExerciseLogDto exerciseLog) {
  final setSummaries = exerciseLog.sets.mapIndexed((index, set) {
    return "Set ${index + 1}: ${exerciseLog.sets[index].summary()}";
  }).toList();
  return setSummaries;
}

/// Single
// Returns the highest weight from WeightAndRepsSetDto instances
WeightAndRepsSetDto? getHighestWeight(List<SetDto> sets) {
  if (sets.isEmpty) return null;

  final weightSets = sets.whereType<WeightAndRepsSetDto>().toList();
  if (weightSets.isEmpty) return null;
  return weightSets.reduce((a, b) => a.weight > b.weight ? a : b);
}

// Returns the heaviest volume (weight * reps) from WeightAndRepsSetDto instances
WeightAndRepsSetDto? getHeaviestVolume(List<SetDto> sets) {
  if (sets.isEmpty) return null;

  final weightSets = sets.whereType<WeightAndRepsSetDto>().toList();
  if (weightSets.isEmpty) return null;
  return weightSets.reduce((a, b) => a.volume() > b.volume() ? a : b);
}

// Returns the highest reps count from RepsSetDto instances
RepsSetDto? getHighestReps(List<SetDto> sets) {
  if (sets.isEmpty) return null;

  final repsSets = sets.whereType<RepsSetDto>().toList();
  if (repsSets.isEmpty) return null;
  return repsSets.reduce((a, b) => a.reps > b.reps ? a : b);
}

// Returns the longest duration from DurationSetDto instances
DurationSetDto? getLongestDuration(List<SetDto> sets) {
  if (sets.isEmpty) return null;

  final durationSets = sets.whereType<DurationSetDto>().toList();
  if (durationSets.isEmpty) return null;
  return durationSets.reduce((a, b) => a.duration > b.duration ? a : b);
}

bool _allDurationSetsEmpty(List<SetDto> sets) {
  // Returns true if every DurationSetDto isEmpty() = true
  return sets.every((set) => set.isEmpty());
}

bool _allWeightsSetsEmpty(List<SetDto> sets) {
  // Returns true if every DurationSetDto isEmpty() = true
  return sets.every((set) => set.isEmpty());
}

bool _allRepsSetsEmpty(List<SetDto> sets) {
  // Returns true if every DurationSetDto isEmpty() = true
  return sets.every((set) => set.isEmpty());
}

bool hasEmptyValues(
    {required List<SetDto> sets, required ExerciseType exerciseType}) {
  return switch (exerciseType) {
    ExerciseType.weights => _allWeightsSetsEmpty(sets),
    ExerciseType.bodyWeight => _allRepsSetsEmpty(sets),
    ExerciseType.duration => _allDurationSetsEmpty(sets),
    ExerciseType.none => true,
  };
}

/// Rep Ranges
class RepRange {
  final int minReps;
  final int maxReps;

  RepRange(this.minReps, this.maxReps);

  @override
  String toString() => 'Min Reps: $minReps, Max Reps: $maxReps)';
}
