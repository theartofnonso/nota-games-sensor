import '../../enums/exercise_type_enums.dart';

class ExerciseDto {
  final String id;
  final String name;
  final ExerciseType type;
  final String notes;
  final bool isSystem;

  const ExerciseDto({
    this.id = "",
    required this.name,
    required this.type,
    this.notes = "",
    this.isSystem = false,
  });

  ExerciseDto copyWith({
    String? id,
    String? name,
    ExerciseType? type,
    String? notes,
    bool? isSystem,
  }) {
    return ExerciseDto(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      isSystem: isSystem ?? this.isSystem,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "type": type.id,
      "notes": notes,
      "isSystem": isSystem,
    };
  }

  factory ExerciseDto.fromJson(Map<String, dynamic> json) {
    final id = json["id"] ?? "";
    final name = json["name"] ?? "";
    final type = json["type"] != null
        ? ExerciseType.fromString(json["type"])
        : ExerciseType.none;

    final notes = json["notes"] ?? "";
    final isSystem =
        json["isSystem"] as bool? ?? id.toString().startsWith('ex-');

    return ExerciseDto(
      id: id,
      name: name,
      type: type,
      notes: notes,
      isSystem: isSystem,
    );
  }

  @override
  String toString() {
    return 'ExerciseDto{id: $id, name: $name, type: $type, notes: $notes, isSystem: $isSystem}';
  }
}
