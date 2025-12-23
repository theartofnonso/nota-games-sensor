import 'package:flutter_test/flutter_test.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';
import 'package:trainware/dtos/appsync/exercise_dto.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';
import 'package:trainware/dtos/set_dtos/weight_and_reps_dto.dart';
import 'package:trainware/dtos/shareable_routine_summary.dart';
import 'package:trainware/enums/exercise_type_enums.dart';

void main() {
  RoutineLogDto buildLog() {
    final start = DateTime.utc(2024, 3, 12, 7, 30, 0);
    final end = start.add(const Duration(hours: 1, minutes: 15, seconds: 10));

    final exercise = ExerciseDto(
      id: "ex1",
      name: "Bench Press",
      type: ExerciseType.weights,
    );

    final sets = [
      WeightAndRepsSetDto(weight: 80, reps: 10, dateTime: start),
      WeightAndRepsSetDto(weight: 90, reps: 8, dateTime: start),
    ];

    final exerciseLog = ExerciseLogDto(
      id: "log-set",
      routineLogId: "routine-1",
      superSetId: "",
      exercise: exercise,
      notes: "",
      sets: sets,
      createdAt: start,
    );

    return RoutineLogDto(
      id: "routine-1",
      templateId: "template-1",
      name: "Push Power",
      exerciseLogs: [exerciseLog],
      startTime: start,
      endTime: end,
    );
  }

  test('formats minimal routine summary values', () {
    final log = buildLog();
    final summary = ShareableRoutineSummary.fromRoutineLog(log);

    expect(summary.routineName, "Push Power");
    expect(summary.durationLabel, "01:15:10");
    expect(summary.exerciseCount, 1);
    expect(summary.setCount, 2);
  });
}
