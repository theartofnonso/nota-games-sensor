import 'package:collection/collection.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainware/dtos/appsync/exercise_dto.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';
import 'package:trainware/dtos/set_dtos/duration_set_dto.dart';
import 'package:trainware/dtos/set_dtos/weight_and_reps_dto.dart';
import 'package:trainware/enums/exercise_type_enums.dart';
import 'package:trainware/repositories/exercise_log_repository.dart';

void main() {
  // Mock exercises
  final lyingLegCurlExercise = ExerciseDto(
    id: "id_lyingLegCurlExercise",
    name: "Lying Leg Curl",
    type: ExerciseType.weights,
    notes: '',
  );

  final plankExercise = ExerciseDto(
    id: "id_plankExercise",
    name: "Plank",
    type: ExerciseType.duration,
    notes: '',
  );

  final benchPressExercise = ExerciseDto(
    id: "id_benchPressExercise",
    name: "Bench Press",
    type: ExerciseType.weights,
    notes: '',
  );

  // Mock exercise logs
  final legCurlExerciseLog = ExerciseLogDto(
    id: lyingLegCurlExercise.id,
    routineLogId: "routineLogId2",
    exercise: lyingLegCurlExercise,
    superSetId: "superSetId",
    notes: "notes",
    sets: [
      WeightAndRepsSetDto(
          weight: 80, reps: 5, checked: true, dateTime: DateTime.now()),
      WeightAndRepsSetDto(
          weight: 100, reps: 8, checked: true, dateTime: DateTime.now()),
      WeightAndRepsSetDto(
          weight: 100, reps: 6, checked: true, dateTime: DateTime.now()),
    ],
    createdAt: DateTime(2023, 12, 1),
  );

  final plankExerciseLog = ExerciseLogDto(
    id: plankExercise.id,
    routineLogId: "routineLogId1",
    superSetId: "superSetId",
    exercise: plankExercise,
    notes: "notes",
    sets: [
      DurationSetDto(
          duration: Duration(milliseconds: 120000),
          checked: true,
          dateTime: DateTime.now()),
      DurationSetDto(
          duration: Duration(milliseconds: 180000),
          checked: true,
          dateTime: DateTime.now()),
      DurationSetDto(
          duration: Duration(milliseconds: 150000),
          checked: true,
          dateTime: DateTime.now()),
    ],
    createdAt: DateTime.now(),
  );

  final benchPressExerciseLog = ExerciseLogDto(
    id: benchPressExercise.id,
    routineLogId: "routineLogId1",
    superSetId: "superSetId",
    exercise: benchPressExercise,
    notes: "notes",
    sets: [
      WeightAndRepsSetDto(
          weight: 80, reps: 15, checked: true, dateTime: DateTime.now()),
      WeightAndRepsSetDto(
          weight: 110, reps: 18, checked: true, dateTime: DateTime.now()),
      WeightAndRepsSetDto(
          weight: 120, reps: 16, checked: true, dateTime: DateTime.now()),
    ],
    createdAt: DateTime(2023, 12, 1),
  );

  test("Remove Exercise Log", () {
    final exerciseLogRepository = ExerciseLogRepository();
    exerciseLogRepository.loadExerciseLogs(exerciseLogs: [
      legCurlExerciseLog,
      plankExerciseLog,
      benchPressExerciseLog
    ]);

    // Act
    exerciseLogRepository.removeExerciseLog(logId: legCurlExerciseLog.id);

    // Assert
    expect(exerciseLogRepository.exerciseLogs.length, 2);
    expect(
        exerciseLogRepository.exerciseLogs
            .firstWhereOrNull((log) => log.id == legCurlExerciseLog.id),
        null);
  });

  test("Update Exercise Log notes", () {
    final exerciseLogRepository = ExerciseLogRepository();
    exerciseLogRepository.loadExerciseLogs(exerciseLogs: [
      legCurlExerciseLog,
      plankExerciseLog,
      benchPressExerciseLog
    ]);

    // Act
    exerciseLogRepository.updateExerciseLogNotes(
        exerciseLogId: plankExerciseLog.id, value: 'This works your core');

    // Assert
    expect(
        exerciseLogRepository.exerciseLogs
            .firstWhereOrNull((log) => log.id == plankExerciseLog.id)
            ?.notes,
        'This works your core');
  });

  test("Super set Exercise Logs", () {
    final exerciseLogRepository = ExerciseLogRepository();
    exerciseLogRepository.loadExerciseLogs(exerciseLogs: [
      legCurlExerciseLog,
      plankExerciseLog,
      benchPressExerciseLog
    ]);

    exerciseLogRepository.addSuperSets(
        firstExerciseLogId: legCurlExerciseLog.id,
        secondExerciseLogId: benchPressExerciseLog.id,
        superSetId:
            "superset_id_${legCurlExerciseLog.id}_${benchPressExerciseLog.id}");

    expect(
        exerciseLogRepository.exerciseLogs
            .firstWhereOrNull((log) => log.id == legCurlExerciseLog.id)
            ?.superSetId,
        "superset_id_${legCurlExerciseLog.id}_${benchPressExerciseLog.id}");

    expect(
        exerciseLogRepository.exerciseLogs
            .firstWhereOrNull((log) => log.id == benchPressExerciseLog.id)
            ?.superSetId,
        "superset_id_${legCurlExerciseLog.id}_${benchPressExerciseLog.id}");
  });

  test("Remove Super set Exercise Logs", () {
    final exerciseLogRepository = ExerciseLogRepository();
    exerciseLogRepository.loadExerciseLogs(exerciseLogs: [
      legCurlExerciseLog,
      plankExerciseLog,
      benchPressExerciseLog
    ]);

    exerciseLogRepository.addSuperSets(
        firstExerciseLogId: legCurlExerciseLog.id,
        secondExerciseLogId: benchPressExerciseLog.id,
        superSetId:
            "superset_id_${legCurlExerciseLog.id}_${benchPressExerciseLog.id}");

    exerciseLogRepository.removeSuperSet(
        superSetId:
            "superset_id_${legCurlExerciseLog.id}_${benchPressExerciseLog.id}");

    expect(
        exerciseLogRepository.exerciseLogs
            .firstWhereOrNull((log) => log.id == legCurlExerciseLog.id)
            ?.superSetId,
        "");
    expect(
        exerciseLogRepository.exerciseLogs
            .firstWhereOrNull((log) => log.id == benchPressExerciseLog.id)
            ?.superSetId,
        "");
  });

  test("Add new set", () {
    final exerciseLogRepository = ExerciseLogRepository();
    exerciseLogRepository.loadExerciseLogs(exerciseLogs: [legCurlExerciseLog]);

    final initialLength = exerciseLogRepository.exerciseLogs
        .firstWhere((log) => log.id == legCurlExerciseLog.id)
        .sets
        .length;

    // Act
    exerciseLogRepository.addSet(
        exerciseLogId: legCurlExerciseLog.id,
        pastSets: legCurlExerciseLog.sets);

    final newLength = exerciseLogRepository.exerciseLogs
        .firstWhere((log) => log.id == legCurlExerciseLog.id)
        .sets
        .length;

    // Assert
    expect(newLength, initialLength + 1);
  });

  test("Remove set by index", () {
    final exerciseLogRepository = ExerciseLogRepository();
    exerciseLogRepository.loadExerciseLogs(exerciseLogs: [legCurlExerciseLog]);

    final initialSets = [
      ...exerciseLogRepository.exerciseLogs
          .firstWhere((log) => log.id == legCurlExerciseLog.id)
          .sets
    ];

    // Act: Remove set at index 1
    exerciseLogRepository.removeSet(
        exerciseLogId: legCurlExerciseLog.id, index: 1);

    final updatedSets = exerciseLogRepository.exerciseLogs
        .firstWhere((log) => log.id == legCurlExerciseLog.id)
        .sets;

    // Assert: The second set (index 1) should now be gone
    expect(updatedSets.length, initialSets.length - 1);
    expect(updatedSets.contains(initialSets[1]), false);
  });

  test("Update weight of a set", () {
    final exerciseLogRepository = ExerciseLogRepository();
    exerciseLogRepository.loadExerciseLogs(exerciseLogs: [legCurlExerciseLog]);

    // Act
    exerciseLogRepository.updateWeight(
        exerciseLogId: legCurlExerciseLog.id,
        index: 0,
        setDto: WeightAndRepsSetDto(
            weight: 90, reps: 15, checked: false, dateTime: DateTime.now()));

    // Assert
    expect(
        (exerciseLogRepository.exerciseLogs.first.sets[0]
                as WeightAndRepsSetDto)
            .weight,
        90);
  });

  test("Update reps of a set", () {
    final exerciseLogRepository = ExerciseLogRepository();
    exerciseLogRepository.loadExerciseLogs(exerciseLogs: [legCurlExerciseLog]);

    exerciseLogRepository.updateWeight(
        exerciseLogId: legCurlExerciseLog.id,
        index: 0,
        setDto: WeightAndRepsSetDto(
            weight: 80, reps: 25, checked: false, dateTime: DateTime.now()));

    expect(
        (exerciseLogRepository.exerciseLogs.first.sets[0]
                as WeightAndRepsSetDto)
            .reps,
        25);
  });

  test("Update check status of a set", () {
    final exerciseLogRepository = ExerciseLogRepository();
    final modifiedLog = legCurlExerciseLog.copyWith(sets: [
      WeightAndRepsSetDto(
          weight: 80, reps: 25, checked: false, dateTime: DateTime.now())
    ]);

    exerciseLogRepository.loadExerciseLogs(exerciseLogs: [modifiedLog]);

    // Act
    exerciseLogRepository.updateSetCheck(
        exerciseLogId: modifiedLog.id,
        index: 0,
        setDto: WeightAndRepsSetDto(
            weight: 80, reps: 25, checked: true, dateTime: DateTime.now()));

    // Assert
    expect(exerciseLogRepository.exerciseLogs[0].sets[0].checked, true);
  });

  test("Clear repository", () {
    final exerciseLogRepository = ExerciseLogRepository();
    exerciseLogRepository.loadExerciseLogs(exerciseLogs: [
      legCurlExerciseLog,
      plankExerciseLog,
      benchPressExerciseLog
    ]);

    exerciseLogRepository.clear();
    expect(exerciseLogRepository.exerciseLogs.length, 0);
  });

  // Additional Tests for Uncovered Methods or Cases

  test("Replace Exercise in a Log", () {
    final exerciseLogRepository = ExerciseLogRepository();
    exerciseLogRepository.loadExerciseLogs(exerciseLogs: [legCurlExerciseLog]);

    // Assuming replaceExercise method exists: it replaces the exercise in the specified log
    final newExercise = plankExercise;
    exerciseLogRepository.replaceExercise(
        oldExerciseId: legCurlExerciseLog.id,
        newExercise: newExercise,
        pastSets: []);

    final updatedLog = exerciseLogRepository.exerciseLogs
        .firstWhere((log) => log.id == newExercise.id);
    expect(updatedLog.exercise.id, newExercise.id);
    expect(updatedLog.exercise.name, newExercise.name);
  });

  test("completedExerciseLogs returns only logs with checked sets", () {
    final exerciseLogRepository = ExerciseLogRepository();

    // We uncheck every set upon loading
    exerciseLogRepository.loadExerciseLogs(exerciseLogs: [
      legCurlExerciseLog,
      plankExerciseLog,
      benchPressExerciseLog
    ]);

    exerciseLogRepository.updateSetCheck(
        exerciseLogId: legCurlExerciseLog.id,
        index: 0,
        setDto: WeightAndRepsSetDto(
            weight: 80, reps: 15, checked: true, dateTime: DateTime.now()));
    exerciseLogRepository.updateSetCheck(
        exerciseLogId: legCurlExerciseLog.id,
        index: 1,
        setDto: WeightAndRepsSetDto(
            weight: 80, reps: 15, checked: true, dateTime: DateTime.now()));
    exerciseLogRepository.updateSetCheck(
        exerciseLogId: legCurlExerciseLog.id,
        index: 2,
        setDto: WeightAndRepsSetDto(
            weight: 80, reps: 15, checked: true, dateTime: DateTime.now()));

    /// Duration Exercises are loaded with without a set, so we need to add new ones everytime because they are logged in realtime
    exerciseLogRepository
        .addSet(exerciseLogId: plankExerciseLog.id, pastSets: []);
    exerciseLogRepository
        .addSet(exerciseLogId: plankExerciseLog.id, pastSets: []);
    exerciseLogRepository
        .addSet(exerciseLogId: plankExerciseLog.id, pastSets: []);
    exerciseLogRepository.updateSetCheck(
        exerciseLogId: plankExerciseLog.id,
        index: 0,
        setDto: DurationSetDto(
            duration: Duration(milliseconds: 120000),
            checked: true,
            dateTime: DateTime.now()));
    exerciseLogRepository.updateSetCheck(
        exerciseLogId: plankExerciseLog.id,
        index: 1,
        setDto: DurationSetDto(
            duration: Duration(milliseconds: 120000),
            checked: true,
            dateTime: DateTime.now()));
    exerciseLogRepository.updateSetCheck(
        exerciseLogId: plankExerciseLog.id,
        index: 2,
        setDto: DurationSetDto(
            duration: Duration(milliseconds: 120000),
            checked: true,
            dateTime: DateTime.now()));

    exerciseLogRepository.updateSetCheck(
        exerciseLogId: benchPressExerciseLog.id,
        index: 0,
        setDto: WeightAndRepsSetDto(
            weight: 80, reps: 15, checked: false, dateTime: DateTime.now()));
    exerciseLogRepository.updateSetCheck(
        exerciseLogId: benchPressExerciseLog.id,
        index: 1,
        setDto: WeightAndRepsSetDto(
            weight: 80, reps: 15, checked: false, dateTime: DateTime.now()));
    exerciseLogRepository.updateSetCheck(
        exerciseLogId: benchPressExerciseLog.id,
        index: 2,
        setDto: WeightAndRepsSetDto(
            weight: 80, reps: 15, checked: false, dateTime: DateTime.now()));

    final completed = exerciseLogRepository.completedExerciseLogs();

    // legCurl and plank logs have checked sets, bench press does not
    expect(completed.length, 2);
    expect(completed.any((log) => log.id == benchPressExerciseLog.id), false);
  });

  test("completedSets returns only the sets that are checked across all logs",
      () {
    final exerciseLogRepository = ExerciseLogRepository();

    // Mock exercise logs
    final legCurlExerciseLog = ExerciseLogDto(
      id: lyingLegCurlExercise.id,
      routineLogId: "routineLogId2",
      exercise: lyingLegCurlExercise,
      superSetId: "superSetId",
      notes: "notes",
      sets: [
        WeightAndRepsSetDto(
            weight: 80, reps: 5, checked: true, dateTime: DateTime.now()),
        WeightAndRepsSetDto(
            weight: 100, reps: 8, checked: true, dateTime: DateTime.now()),
        WeightAndRepsSetDto(
            weight: 100, reps: 6, checked: true, dateTime: DateTime.now()),
      ],
      createdAt: DateTime(2023, 12, 1),
    );

    final benchPressExerciseLog = ExerciseLogDto(
      id: benchPressExercise.id,
      routineLogId: "routineLogId1",
      superSetId: "superSetId",
      exercise: benchPressExercise,
      notes: "notes",
      sets: [
        WeightAndRepsSetDto(
            weight: 80, reps: 15, checked: true, dateTime: DateTime.now()),
        WeightAndRepsSetDto(
            weight: 110, reps: 18, checked: true, dateTime: DateTime.now()),
        WeightAndRepsSetDto(
            weight: 120, reps: 16, checked: true, dateTime: DateTime.now()),
      ],
      createdAt: DateTime(2023, 12, 1),
    );

    // We uncheck every set upon loading
    exerciseLogRepository.loadExerciseLogs(
        exerciseLogs: [benchPressExerciseLog, legCurlExerciseLog]);

    exerciseLogRepository.updateSetCheck(
        exerciseLogId: legCurlExerciseLog.id,
        index: 0,
        setDto: WeightAndRepsSetDto(
            weight: 80, reps: 15, checked: false, dateTime: DateTime.now()));
    exerciseLogRepository.updateSetCheck(
        exerciseLogId: legCurlExerciseLog.id,
        index: 1,
        setDto: WeightAndRepsSetDto(
            weight: 80, reps: 15, checked: true, dateTime: DateTime.now()));
    exerciseLogRepository.updateSetCheck(
        exerciseLogId: legCurlExerciseLog.id,
        index: 2,
        setDto: WeightAndRepsSetDto(
            weight: 80, reps: 15, checked: true, dateTime: DateTime.now()));

    exerciseLogRepository.updateSetCheck(
        exerciseLogId: benchPressExerciseLog.id,
        index: 0,
        setDto: WeightAndRepsSetDto(
            weight: 80, reps: 15, checked: false, dateTime: DateTime.now()));
    exerciseLogRepository.updateSetCheck(
        exerciseLogId: benchPressExerciseLog.id,
        index: 1,
        setDto: WeightAndRepsSetDto(
            weight: 80, reps: 15, checked: true, dateTime: DateTime.now()));
    exerciseLogRepository.updateSetCheck(
        exerciseLogId: benchPressExerciseLog.id,
        index: 2,
        setDto: WeightAndRepsSetDto(
            weight: 80, reps: 15, checked: true, dateTime: DateTime.now()));

    final completed = exerciseLogRepository.completedSets();

    expect(completed.length, 4);
  });

  test("Attempting to remove a non-existent log should not crash", () {
    final exerciseLogRepository = ExerciseLogRepository();
    exerciseLogRepository.loadExerciseLogs(exerciseLogs: [legCurlExerciseLog]);

    // Non-existent ID
    exerciseLogRepository.removeExerciseLog(logId: "non_existent_id");
    // No crash and no changes
    expect(exerciseLogRepository.exerciseLogs.length, 1);
  });

  test("Attempting to remove a non-existent set should not crash", () {
    final exerciseLogRepository = ExerciseLogRepository();
    exerciseLogRepository.loadExerciseLogs(exerciseLogs: [legCurlExerciseLog]);

    // Index out of range
    exerciseLogRepository.removeSet(
        exerciseLogId: legCurlExerciseLog.id, index: 999);
    // No crash and no changes
    final updatedLog = exerciseLogRepository.exerciseLogs
        .firstWhere((log) => log.id == legCurlExerciseLog.id);
    expect(updatedLog.sets.length, legCurlExerciseLog.sets.length);
  });

  test("Loading empty exercise logs should result in empty repository", () {
    final exerciseLogRepository = ExerciseLogRepository();

    exerciseLogRepository.loadExerciseLogs(exerciseLogs: []);

    expect(exerciseLogRepository.exerciseLogs.isEmpty, true);
  });
}
