import 'package:tracker_app/enums/muscle_group_enums.dart';

import '../../enums/exercise_type_enums.dart';

class ExerciseDto {
  final String id;
  final String name;
  final ExerciseType type;
  final MuscleGroup primaryMuscleGroup;
  final String notes;

  const ExerciseDto({
    this.id = "",
    required this.name,
    required this.type,
    required this.primaryMuscleGroup,
    this.notes = "",
  });

  ExerciseDto copyWith({
    String? id,
    String? name,
    ExerciseType? type,
    MuscleGroup? primaryMuscleGroup,
    String? notes,
  }) {
    return ExerciseDto(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      primaryMuscleGroup: primaryMuscleGroup ?? this.primaryMuscleGroup,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "type": type.id,
      "primaryMuscleGroup": primaryMuscleGroup.name,
      "notes": notes,
    };
  }

  factory ExerciseDto.fromJson(Map<String, dynamic> json) {
    final id = json["id"] ?? "";
    final name = json["name"] ?? "";
    final type = json["type"] != null
        ? ExerciseType.fromString(json["type"])
        : ExerciseType.weights;
    final primaryMuscleGroup = MuscleGroup.values
        .firstWhere((e) => e.name == json["primaryMuscleGroup"]);
    final notes = json["notes"] ?? "";

    return ExerciseDto(
      id: id,
      name: name,
      type: type,
      primaryMuscleGroup: primaryMuscleGroup,
      notes: notes,
    );
  }

  @override
  String toString() {
    return 'ExerciseDto{id: $id, name: $name, type: $type, primaryMuscleGroup: $primaryMuscleGroup, notes: $notes}';
  }
}
