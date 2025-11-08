// Helper function to create a mock ExerciseDto with a specified primary muscle group.
import 'package:tracker_app/dtos/appsync/exercise_dto.dart';
import 'package:tracker_app/dtos/exercise_log_dto.dart';
import 'package:tracker_app/dtos/set_dtos/set_dto.dart';
import 'package:tracker_app/dtos/set_dtos/weight_and_reps_dto.dart';
import 'package:tracker_app/enums/exercise_type_enums.dart';
import 'package:tracker_app/enums/muscle_group_enums.dart';

ExerciseDto makeExercise({
  required String id,
  required ExerciseType type,
  required MuscleGroup primary,
  String name = 'Test Exercise',
}) {
  return ExerciseDto(
    id: id,
    name: name,
    type: type,
    primaryMuscleGroup: primary,
    notes: '',
  );
}

// Helper to create a log with given exercise and sets. By default, sets is empty since we just need muscle groups info.
ExerciseLogDto makeLog({
  required ExerciseDto exercise,
  DateTime? createdAt,
  List<SetDto> sets = const [],
}) {
  return ExerciseLogDto(
    id: exercise.id,
    exercise: exercise,
    sets: sets.isNotEmpty
        ? sets
        : [
            WeightAndRepsSetDto(
                weight: 10, reps: 12, checked: true, dateTime: createdAt)
          ],
    createdAt: createdAt ?? DateTime.now(),
    routineLogId: 'routine1',
    superSetId: '',
    notes: '',
  );
}
