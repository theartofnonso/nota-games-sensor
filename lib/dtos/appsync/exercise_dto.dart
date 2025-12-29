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
    final id = json["id"] as String? ?? "";
    final name = json["name"] as String;
    final type = ExerciseType.fromString(json["type"] as String);
    final notes = json["notes"] as String? ?? "";
    final isSystem = json["isSystem"] as bool? ?? false;

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
