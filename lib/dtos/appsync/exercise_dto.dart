import 'package:tracker_app/enums/muscle_group_enums.dart';

import '../../enums/exercise_type_enums.dart';

class ExerciseDto {
  final String id;
  final String name;
  final ExerciseType type;
  final MuscleGroup primaryMuscleGroup;
  final List<MuscleGroup> secondaryMuscleGroups;
  final String notes;
  final String? imageUrl;
  final String? description;
  final bool owner;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ExerciseDto({
    this.id = "",
    required this.name,
    required this.type,
    required this.primaryMuscleGroup,
    required this.secondaryMuscleGroups,
    this.notes = "",
    this.imageUrl,
    this.description,
    required this.owner,
    required this.createdAt,
    required this.updatedAt,
  });

  ExerciseDto copyWith({
    String? id,
    String? name,
    ExerciseType? type,
    MuscleGroup? primaryMuscleGroup,
    List<MuscleGroup>? secondaryMuscleGroups,
    String? notes,
    String? imageUrl,
    String? description,
    bool? owner,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ExerciseDto(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      primaryMuscleGroup: primaryMuscleGroup ?? this.primaryMuscleGroup,
      secondaryMuscleGroups:
          secondaryMuscleGroups ?? this.secondaryMuscleGroups,
      notes: notes ?? this.notes,
      imageUrl: imageUrl ?? this.imageUrl,
      description: description ?? this.description,
      owner: owner ?? this.owner,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "name": name,
      "type": type.name,
      "primaryMuscleGroup": primaryMuscleGroup.name,
      "secondaryMuscleGroups":
          secondaryMuscleGroups.map((e) => e.name).toList(),
      "notes": notes,
      "imageUrl": imageUrl,
      "description": description,
      "owner": owner,
      "createdAt": createdAt.toIso8601String(),
      "updatedAt": updatedAt.toIso8601String(),
    };
  }

  factory ExerciseDto.fromJson(Map<String, dynamic> json) {
    final id = json["id"] ?? "";
    final name = json["name"] ?? "";
    final type = ExerciseType.values.firstWhere(
      (e) => e.name == json["type"],
      orElse: () => ExerciseType.weights,
    );
    final primaryMuscleGroup = MuscleGroup.values.firstWhere(
      (e) => e.name == json["primaryMuscleGroup"],
      orElse: () => MuscleGroup.chest,
    );
    final secondaryMuscleGroups =
        (json["secondaryMuscleGroups"] as List<dynamic>?)
                ?.map((e) => MuscleGroup.values.firstWhere(
                      (mg) => mg.name == e,
                      orElse: () => MuscleGroup.chest,
                    ))
                .toList() ??
            [];
    final notes = json["notes"] ?? "";
    final imageUrl = json["imageUrl"];
    final description = json["description"];
    final owner = json["owner"] ?? false;
    final createdAt = json["createdAt"] != null
        ? DateTime.parse(json["createdAt"])
        : DateTime.now();
    final updatedAt = json["updatedAt"] != null
        ? DateTime.parse(json["updatedAt"])
        : DateTime.now();

    return ExerciseDto(
      id: id,
      name: name,
      type: type,
      primaryMuscleGroup: primaryMuscleGroup,
      secondaryMuscleGroups: secondaryMuscleGroups,
      notes: notes,
      imageUrl: imageUrl,
      description: description,
      owner: owner,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  String toString() {
    return 'ExerciseDto{id: $id, name: $name, type: $type, primaryMuscleGroup: $primaryMuscleGroup, secondaryMuscleGroups: $secondaryMuscleGroups, notes: $notes, imageUrl: $imageUrl, description: $description, owner: $owner, createdAt: $createdAt, updatedAt: $updatedAt}';
  }
}
