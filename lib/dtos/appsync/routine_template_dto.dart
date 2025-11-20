import 'package:trainware/dtos/appsync/routine_log_dto.dart';

import '../exercise_log_dto.dart';

class RoutineTemplateDto {
  final String id;
  final String planId;
  final String name;
  final List<ExerciseLogDto> exerciseTemplates;

  RoutineTemplateDto({
    this.id = "",
    this.planId = "",
    required this.name,
    required this.exerciseTemplates,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'planId': planId,
      'name': name,
      'exercises':
          exerciseTemplates.map((exercise) => exercise.toJson()).toList(),
    };
  }

  factory RoutineTemplateDto.fromJson({required Map<String, dynamic> json}) {
    final id = json["id"] ?? "";
    final planId = json["planId"] ?? "";
    final name = json["name"] ?? "";

    final rawExerciseTemplates = json["exercises"] as List<dynamic>;
    final exerciseTemplates = rawExerciseTemplates.map((exerciseJson) {
      return ExerciseLogDto.fromJson(
        routineLogId: id,
        json: exerciseJson,
        createdAt: DateTime.now(),
      );
    }).toList();

    return RoutineTemplateDto(
      id: id,
      planId: planId,
      name: name,
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
    List<ExerciseLogDto>? exerciseTemplates,
  }) {
    return RoutineTemplateDto(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      name: name ?? this.name,
      exerciseTemplates: exerciseTemplates != null
          ? exerciseTemplates.map((e) => e.copyWith()).toList()
          : this.exerciseTemplates.map((e) => e.copyWith()).toList(),
    );
  }

  @override
  String toString() {
    return 'RoutineTemplateDto{id: $id, planId: $planId, name: $name, exerciseTemplates: $exerciseTemplates}';
  }
}
