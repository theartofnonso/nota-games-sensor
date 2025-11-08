import 'package:flutter_test/flutter_test.dart';
import 'package:tracker_app/dtos/appsync/exercise_dto.dart';
import 'package:tracker_app/dtos/exercise_log_dto.dart';
import 'package:tracker_app/dtos/set_dtos/duration_set_dto.dart';
import 'package:tracker_app/dtos/set_dtos/reps_dto.dart';
import 'package:tracker_app/dtos/set_dtos/set_dto.dart';
import 'package:tracker_app/dtos/set_dtos/weight_and_reps_dto.dart';
import 'package:tracker_app/enums/exercise_type_enums.dart';
import 'package:tracker_app/enums/muscle_group_enums.dart';
import 'package:tracker_app/enums/pb_enums.dart';
import 'package:tracker_app/enums/template_changes_type_message_enums.dart';
import 'package:tracker_app/utils/exercise_logs_utils.dart';

void main() {
  // Helper function to create a WeightAndRepsSetDto for convenience
  WeightAndRepsSetDto weightSet(
      {double weight = 50.0, int reps = 10, bool checked = true}) {
    return WeightAndRepsSetDto(
        weight: weight, reps: reps, checked: checked, dateTime: DateTime.now());
  }

  RepsSetDto repsSet({int reps = 15, bool checked = true}) {
    return RepsSetDto(reps: reps, checked: checked, dateTime: DateTime.now());
  }

  DurationSetDto durationSet(
      {Duration duration = const Duration(seconds: 30), bool checked = true}) {
    return DurationSetDto(
        duration: duration, checked: checked, dateTime: DateTime.now());
  }

  // Mock Exercise DTOs
  final weightExercise = ExerciseDto(
      id: 'ex_weight',
      name: 'Bench Press',
      type: ExerciseType.weights,
      primaryMuscleGroup: MuscleGroup.chest,
      secondaryMuscleGroups: [],
      notes: '',
      owner: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now());
  final bodyWeightExercise = ExerciseDto(
      id: 'ex_body',
      name: 'Push-ups',
      type: ExerciseType.bodyWeight,
      primaryMuscleGroup: MuscleGroup.chest,
      secondaryMuscleGroups: [],
      notes: '',
      owner: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now());
  final durationExercise = ExerciseDto(
      id: 'ex_duration',
      name: 'Plank',
      type: ExerciseType.duration,
      primaryMuscleGroup: MuscleGroup.abs,
      secondaryMuscleGroups: [],
      notes: '',
      owner: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now());

  // Mock Exercise Logs
  ExerciseLogDto makeLog(ExerciseDto exercise, List<SetDto> sets,
      {DateTime? createdAt,
      String routineLogId = 'log1',
      String superSetId = '',
      String notes = ''}) {
    return ExerciseLogDto(
      id: exercise.id,
      exercise: exercise,
      sets: sets,
      routineLogId: routineLogId,
      superSetId: superSetId,
      createdAt: createdAt ?? DateTime.now(),
      notes: notes,
    );
  }

  group('Weight and Reps Functions', () {
    test('heaviestWeightInSetForExerciseLog returns set with heaviest weight',
        () {
      final log = makeLog(weightExercise, [
        weightSet(weight: 40),
        weightSet(weight: 60),
        weightSet(weight: 55)
      ]);

      final heaviestSet = heaviestWeightInSetForExerciseLog(exerciseLog: log);
      expect(heaviestSet.weight, 60.0);
    });

    test('heaviestWeightInSetForExerciseLog returns 0 set for no weight sets',
        () {
      final log = makeLog(bodyWeightExercise, [repsSet()]);
      final heaviestSet = heaviestWeightInSetForExerciseLog(exerciseLog: log);
      expect(heaviestSet.weight, 0);
    });

    test('heaviestVolumeForExerciseLog returns highest volume', () {
      final log = makeLog(weightExercise,
          [weightSet(weight: 50, reps: 10), weightSet(weight: 40, reps: 15)]);
      // 50*10=500 vs 40*15=600 -> highest volume = 600
      expect(heaviestVolumeForExerciseLog(exerciseLog: log), 600.0);
    });

    test('heaviestSetVolumeForExerciseLog returns set with highest volume', () {
      final log = makeLog(weightExercise, [
        weightSet(weight: 100, reps: 1),
        weightSet(weight: 40, reps: 15)
      ] // volumes: 100 and 600
          );
      final heaviestSet = heaviestSetVolumeForExerciseLog(exerciseLog: log);
      expect(heaviestSet.weight, 40);
      expect(heaviestSet.reps, 15);
    });
  });

  group('Duration Functions', () {
    test('longestDurationForExerciseLog returns the longest duration set', () {
      final log = makeLog(durationExercise, [
        durationSet(duration: Duration(seconds: 30)),
        durationSet(duration: Duration(seconds: 45))
      ]);
      expect(longestDurationForExerciseLog(exerciseLog: log),
          Duration(seconds: 45));
    });

    test('totalDurationExerciseLog sums all duration sets', () {
      final log = makeLog(durationExercise, [
        durationSet(duration: Duration(seconds: 30)),
        durationSet(duration: Duration(seconds: 30)),
        durationSet(duration: Duration(seconds: 40)),
      ]);
      expect(
          totalDurationExerciseLog(exerciseLog: log), Duration(seconds: 100));
    });
  });

  group('Reps Functions', () {
    test('totalRepsForExerciseLog returns sum of reps for bodyweight exercise',
        () {
      final log =
          makeLog(bodyWeightExercise, [repsSet(reps: 10), repsSet(reps: 20)]);
      expect(totalRepsForExerciseLog(exerciseLog: log), 30);
    });

    test('highestRepsForExerciseLog returns the highest single set of reps',
        () {
      final log = makeLog(bodyWeightExercise,
          [repsSet(reps: 8), repsSet(reps: 20), repsSet(reps: 15)]);
      expect(highestRepsForExerciseLog(exerciseLog: log), 20);
    });

    test('highestRepsForExerciseLog returns 0 if no rep sets', () {
      final log = makeLog(durationExercise, [durationSet()]);
      expect(highestRepsForExerciseLog(exerciseLog: log), 0);
    });
  });

  group('Aggregated Logs Functions', () {
    test(
        'mostRepsInSet returns logId and highest single-set reps across multiple logs',
        () {
      final logs = [
        makeLog(bodyWeightExercise, [repsSet(reps: 10)], routineLogId: 'logA'),
        makeLog(bodyWeightExercise, [repsSet(reps: 20)], routineLogId: 'logB'),
        makeLog(bodyWeightExercise, [repsSet(reps: 15)], routineLogId: 'logC'),
      ];
      final (id, reps) = mostRepsInSet(exerciseLogs: logs);
      expect(id, 'logB');
      expect(reps, 20);
    });

    test('mostRepsInSession returns logId with total highest reps', () {
      final logs = [
        makeLog(bodyWeightExercise, [repsSet(reps: 10), repsSet(reps: 5)],
            routineLogId: 'logA'), // total = 15
        makeLog(bodyWeightExercise, [repsSet(reps: 20), repsSet(reps: 10)],
            routineLogId: 'logB'), // total = 30
      ];
      final (id, total) = mostRepsInSession(exerciseLogs: logs);
      expect(id, 'logB');
      expect(total, 30);
    });

    test('longestDuration finds the longest duration across logs', () {
      final logs = [
        makeLog(
            durationExercise, [durationSet(duration: Duration(seconds: 30))],
            routineLogId: 'logA'),
        makeLog(
            durationExercise, [durationSet(duration: Duration(seconds: 90))],
            routineLogId: 'logB'),
        makeLog(
            durationExercise, [durationSet(duration: Duration(seconds: 60))],
            routineLogId: 'logC'),
      ];
      final (id, duration) = longestDuration(exerciseLogs: logs);
      expect(id, 'logB');
      expect(duration, Duration(seconds: 90));
    });
  });

  group('PB Calculations', () {
    test('calculatePBs returns PB for heavier weight than any past log', () {
      final pastLogs = [
        makeLog(weightExercise, [weightSet(weight: 50, reps: 10)],
            routineLogId: 'oldLog'),
      ];
      final currentLog = makeLog(
          weightExercise, [weightSet(weight: 60, reps: 5)],
          routineLogId: 'newLog');

      final pbs = calculatePBs(
          pastExerciseLogs: pastLogs,
          exerciseType: weightExercise.type,
          exerciseLog: currentLog);
      expect(pbs.length, 1);
      expect(pbs.first.pb, PBType.weight);
    });

    test('calculatePBs returns PB for longer duration than any past log', () {
      final pastLogs = [
        makeLog(
            durationExercise, [durationSet(duration: Duration(seconds: 30))],
            routineLogId: 'oldLog'),
      ];
      final currentLog = makeLog(
          durationExercise, [durationSet(duration: Duration(seconds: 45))],
          routineLogId: 'newLog');

      final pbs = calculatePBs(
          pastExerciseLogs: pastLogs,
          exerciseType: durationExercise.type,
          exerciseLog: currentLog);
      expect(pbs.length, 1);
      expect(pbs.first.pb, PBType.duration);
    });
  });

  group('Template Changes', () {
    final logs1 = [
      makeLog(bodyWeightExercise, [repsSet(reps: 10)], routineLogId: 'log1'),
      makeLog(weightExercise, [weightSet(weight: 50)], routineLogId: 'log1'),
    ];

    final logs2 = [
      makeLog(bodyWeightExercise, [repsSet(reps: 10)], routineLogId: 'log2'),
    ];

    test('hasDifferentExerciseLogsLength detects difference in number of logs',
        () {
      expect(
          hasDifferentExerciseLogsLength(
              exerciseLogs1: logs1, exerciseLogs2: logs2),
          TemplateChange.exerciseLogLength);
      expect(
          hasDifferentExerciseLogsLength(
              exerciseLogs1: logs1, exerciseLogs2: logs1),
          null);
    });

    test('hasReOrderedExercises detects exercise order changes', () {
      final reordered = [
        makeLog(weightExercise, [weightSet(weight: 50)], routineLogId: 'log1'),
        makeLog(bodyWeightExercise, [repsSet(reps: 10)], routineLogId: 'log1'),
      ];
      expect(
          hasReOrderedExercises(exerciseLogs1: logs1, exerciseLogs2: reordered),
          TemplateChange.exerciseOrder);
    });

    test('hasDifferentSetsLength detects difference in total sets', () {
      final moreSets = [
        makeLog(bodyWeightExercise, [repsSet(reps: 10), repsSet(reps: 5)],
            routineLogId: 'log1'),
        makeLog(weightExercise, [weightSet(weight: 50)], routineLogId: 'log1'),
      ];
      expect(
          hasDifferentSetsLength(exerciseLogs1: logs1, exerciseLogs2: moreSets),
          TemplateChange.setsLength);
      expect(hasDifferentSetsLength(exerciseLogs1: logs1, exerciseLogs2: logs1),
          null);
    });

    test('hasExercisesChanged detects when exercises are not the same', () {
      final differentExercise = [
        makeLog(
            durationExercise, [durationSet(duration: Duration(seconds: 30))],
            routineLogId: 'log1'),
        makeLog(weightExercise, [weightSet(weight: 50)], routineLogId: 'log1'),
      ];

      expect(
          hasExercisesChanged(
              exerciseLogs1: logs1, exerciseLogs2: differentExercise),
          TemplateChange.exerciseLogChange);
    });

    test('hasSuperSetIdChanged detects changes in superSetIds', () {
      final superSetLogs = [
        makeLog(bodyWeightExercise, [repsSet(reps: 10)],
            routineLogId: 'log1', superSetId: 'super1'),
        makeLog(weightExercise, [weightSet(weight: 50)],
            routineLogId: 'log1', superSetId: 'super1'),
      ];

      expect(
          hasSuperSetIdChanged(
              exerciseLogs1: logs1, exerciseLogs2: superSetLogs),
          TemplateChange.supersetId);
    });

    test('hasCheckedSetsChanged detects changes in checked sets', () {
      final uncheckedLogs = [
        makeLog(bodyWeightExercise, [repsSet(reps: 10, checked: false)],
            routineLogId: 'log1'),
        makeLog(weightExercise, [weightSet(weight: 50, checked: false)],
            routineLogId: 'log1'),
      ];

      expect(
          hasCheckedSetsChanged(
              exerciseLogs1: logs1, exerciseLogs2: uncheckedLogs),
          TemplateChange.checkedSets);
    });

    test('hasSetValueChanged detects changes in set values', () {
      final changedVolume = [
        makeLog(bodyWeightExercise, [repsSet(reps: 20)], routineLogId: 'log1'),
        makeLog(weightExercise, [weightSet(weight: 50)], routineLogId: 'log1'),
      ];
      expect(
          hasSetValueChanged(
              exerciseLogs1: logs1, exerciseLogs2: changedVolume),
          TemplateChange.setValue);
    });
  });

  group('Helper Functions for Exercise Types', () {
    test('withWeightsOnly returns true for weights, false otherwise', () {
      expect(withWeightsOnly(type: ExerciseType.weights), true);
      expect(withWeightsOnly(type: ExerciseType.bodyWeight), false);
    });

    test('withReps returns true for bodyweight and weights, false for duration',
        () {
      expect(withReps(type: ExerciseType.weights), true);
      expect(withReps(type: ExerciseType.bodyWeight), true);
      expect(withReps(type: ExerciseType.duration), false);
    });

    test('withRepsOnly returns true for bodyweight only', () {
      expect(withRepsOnly(type: ExerciseType.bodyWeight), true);
      expect(withRepsOnly(type: ExerciseType.weights), false);
    });

    test('withDurationOnly returns true for duration type only', () {
      expect(withDurationOnly(type: ExerciseType.duration), true);
      expect(withDurationOnly(type: ExerciseType.weights), false);
    });
  });

  group('loggedExercises', () {
    test('loggedExercises returns only exercises with checked sets', () {
      final logs = [
        makeLog(bodyWeightExercise, [repsSet(reps: 10, checked: true)]),
        makeLog(weightExercise, [weightSet(weight: 50, checked: false)])
      ];

      final completed = loggedExercises(exerciseLogs: logs);
      expect(completed.length, 1);
      expect(completed.first.exercise.id, bodyWeightExercise.id);
    });
  });
}
