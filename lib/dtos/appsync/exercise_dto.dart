import '../../enums/exercise_type_enums.dart';

class ExerciseDto {
  final String id;
  final String name;
  final ExerciseType type;
  final String notes;

  const ExerciseDto({
    this.id = "",
    required this.name,
    required this.type,
    this.notes = "",
  });

  ExerciseDto copyWith({
    String? id,
    String? name,
    ExerciseType? type,
    String? notes,
  }) {
    return ExerciseDto(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "type": type.id,
      "notes": notes,
    };
  }

  factory ExerciseDto.fromJson(Map<String, dynamic> json) {
    final id = json["id"] ?? "";
    final name = json["name"] ?? "";
    final type = json["type"] != null
        ? ExerciseType.fromString(json["type"])
        : ExerciseType.weights;

    final notes = json["notes"] ?? "";

    return ExerciseDto(
      id: id,
      name: name,
      type: type,
      notes: notes,
    );
  }

  @override
  String toString() {
    return 'ExerciseDto{id: $id, name: $name, type: $type, notes: $notes}';
  }
}
