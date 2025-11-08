import 'package:tracker_app/dtos/appsync/routine_log_dto.dart';
import 'package:tracker_app/dtos/appsync/routine_plan_dto.dart';

import '../exercise_log_dto.dart';

class RoutineTemplateDto {
  final String id;
  final String planId;
  final String name;
  final String notes;
  final List<ExerciseLogDto> exerciseTemplates;
  final String owner;
  final DateTime createdAt;
  final DateTime updatedAt;

  RoutineTemplateDto({
    required this.id,
    this.planId = "",
    required this.name,
    required this.exerciseTemplates,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.owner,
  });

  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "planId": planId,
      'name': name,
      'notes': notes,
      'exercises': exerciseTemplates.map((exercise) => exercise.toJson()).toList(),
      'owner': owner,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory RoutineTemplateDto.fromJson({required Map<String, dynamic> json}) {
    final id = json["id"] ?? "";
    final String? rawPlanId = json['planId'] as String?;
    final String planId = (rawPlanId?.isNotEmpty ?? false) ? rawPlanId! : defaultPlanId;
    final name = json["name"] ?? "";
    final notes = json["notes"] ?? "";
    final owner = json["owner"] ?? "";
    final createdAt = json["createdAt"] != null ? DateTime.parse(json["createdAt"]) : DateTime.now();
    final updatedAt = json["updatedAt"] != null ? DateTime.parse(json["updatedAt"]) : DateTime.now();
    
    final rawExerciseTemplates = json["exercises"] as List<dynamic>;
    final exerciseTemplates = rawExerciseTemplates.map((exerciseJson) {
      return ExerciseLogDto.fromJson(
        routineLogId: id,
        json: exerciseJson,
        createdAt: createdAt,
      );
    }).toList();

    return RoutineTemplateDto(
      id: id,
      planId: planId,
      name: name,
      exerciseTemplates: exerciseTemplates,
      notes: notes,
      owner: owner,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  RoutineLogDto toLog() {
    return RoutineLogDto(
        id: "",
        templateId: id,
        name: name,
        exerciseLogs: List.from(exerciseTemplates),
        notes: notes,
        owner: owner,
        startTime: DateTime.now(),
        endTime: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now());
  }

  RoutineTemplateDto copyWith({
    String? id,
    String? planId,
    String? name,
    String? notes,
    List<ExerciseLogDto>? exerciseTemplates,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? owner,
  }) {
    return RoutineTemplateDto(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      exerciseTemplates: exerciseTemplates != null
          ? exerciseTemplates.map((e) => e.copyWith()).toList()
          : this.exerciseTemplates.map((e) => e.copyWith()).toList(),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      owner: owner ?? this.owner,
    );
  }

  @override
  String toString() {
    return 'RoutineTemplateDto{id: $id, planId: $planId, name: $name, notes: $notes, exerciseTemplates: $exerciseTemplates, owner: $owner, createdAt: $createdAt, updatedAt: $updatedAt}';
  }
}
