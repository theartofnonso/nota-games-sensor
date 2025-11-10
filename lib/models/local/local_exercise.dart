import 'package:isar/isar.dart';

part 'local_exercise.g.dart';

@collection
class LocalExercise {
  Id id = Isar.autoIncrement;

  @Index(unique: true)
  late String exerciseId; // UUID from DTO

  late String jsonData; // Serialized ExerciseDto

  @Index()
  late String name; // For searching

  @Index()
  late String type; // For filtering

  @Index()
  late String primaryMuscleGroup; // For filtering

  late DateTime lastModifiedLocal;

  late bool needsSync;

  String? syncError;

  late DateTime createdAt;

  // Constructor
  LocalExercise();
}
