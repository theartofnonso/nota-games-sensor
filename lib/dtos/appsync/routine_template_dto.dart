import 'package:trainware/dtos/appsync/routine_log_dto.dart';

import '../exercise_log_dto.dart';

class RoutineTemplateDto {
  final String id;
  final String planId;
  final String name;
  final String notes;
  final List<ExerciseLogDto> exerciseTemplates;

  RoutineTemplateDto({
    this.id = "",
    required this.planId,
    required this.name,
    this.notes = "",
    required this.exerciseTemplates,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'planId': planId,
      'name': name,
      'notes': notes,
      'exercises':
          exerciseTemplates.map((exercise) => exercise.toJson()).toList(),
    };
  }

  factory RoutineTemplateDto.fromJson({required Map<String, dynamic> json}) {
    final id = json["id"] ?? "";
    final planId = json["planId"] ?? "";
    final name = json["name"] ?? "";
    final notes = json["notes"] ?? "";

    final rawExerciseTemplates = json["exercises"];
    if (rawExerciseTemplates is! List) {
      throw const FormatException(
          'Invalid routine template payload: exercises must be a list');
    }

    final exerciseTemplates = <ExerciseLogDto>[];
    for (var i = 0; i < rawExerciseTemplates.length; i++) {
      final exerciseJson = rawExerciseTemplates[i];
      if (exerciseJson is! Map<String, dynamic>) {
        throw FormatException(
            'Invalid routine template payload at index $i: exercise entry must be an object');
      }
      final parsed = ExerciseLogDto.safeFromJson(
        routineLogId: id,
        json: exerciseJson,
        createdAt: DateTime.now(),
      );
      if (parsed != null) {
        exerciseTemplates.add(parsed);
      }
    }

    return RoutineTemplateDto(
      id: id,
      planId: planId,
      name: name,
      notes: notes,
      exerciseTemplates: exerciseTemplates,
    );
  }

  RoutineLogDto toLog() {
    return RoutineLogDto(
        id: "",
        templateId: id,
        name: name,
        exerciseLogs: List.from(exerciseTemplates),
        startTime: DateTime.now(),
        endTime: DateTime.now());
  }

  RoutineTemplateDto copyWith({
    String? id,
    String? planId,
    String? name,
    String? notes,
    List<ExerciseLogDto>? exerciseTemplates,
  }) {
    return RoutineTemplateDto(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      exerciseTemplates: exerciseTemplates != null
          ? exerciseTemplates.map((e) => e.copyWith()).toList()
          : this.exerciseTemplates.map((e) => e.copyWith()).toList(),
    );
  }

  @override
  String toString() {
    return 'RoutineTemplateDto{id: $id, planId: $planId, name: $name, notes: $notes, exerciseTemplates: $exerciseTemplates}';
  }
}
