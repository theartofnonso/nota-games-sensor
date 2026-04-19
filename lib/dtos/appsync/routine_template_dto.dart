import 'package:trainware/dtos/appsync/routine_log_dto.dart';

import '../exercise_log_dto.dart';

class RoutineTemplateDto {
  final String id;
  final String planId;
  final String name;
  final String notes;
  final List<ExerciseLogDto> exerciseTemplates;
  final String? clientId;
  /// Owner user id. Coach-created templates have owner = coach; client-created have owner = client.
  final String? owner;
  /// Display order within [planId]; lower values first. Null for legacy rows (tie-break elsewhere).
  final int? planOrderIndex;

  RoutineTemplateDto({
    this.id = "",
    required this.planId,
    required this.name,
    this.notes = "",
    required this.exerciseTemplates,
    this.clientId,
    this.owner,
    this.planOrderIndex,
  });

  /// True when the template was created by the given user (they can edit/delete).
  bool isOwnedBy(String userId) =>
      owner != null && owner!.isNotEmpty && owner == userId;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'planId': planId,
      'name': name,
      'notes': notes,
      'exercises':
          exerciseTemplates.map((exercise) => exercise.toJson()).toList(),
      'clientId': clientId,
      'owner': owner,
      'planOrderIndex': planOrderIndex,
    };
  }

  factory RoutineTemplateDto.fromJson({required Map<String, dynamic> json}) {
    final id = json["id"] as String? ?? "";
    final planId = json["planId"] as String;
    final name = json["name"] as String;
    final notes = json["notes"] as String? ?? "";
    final clientId = json["clientId"] as String?;
    final owner = json["owner"] as String?;
    final planOrderIndex = (json["planOrderIndex"] as num?)?.toInt();

    final rawExerciseTemplates = json["exercises"] as List;
    final exerciseTemplates = rawExerciseTemplates
        .map((exerciseJson) => ExerciseLogDto.fromJson(
              routineLogId: id,
              json: exerciseJson as Map<String, dynamic>,
              createdAt: DateTime.now(),
            ))
        .toList();

    return RoutineTemplateDto(
      id: id,
      planId: planId,
      name: name,
      notes: notes,
      exerciseTemplates: exerciseTemplates,
      clientId: clientId,
      owner: owner,
      planOrderIndex: planOrderIndex,
    );
  }

  RoutineLogDto toLog() {
    return RoutineLogDto(
        id: "",
        templateId: id,
        name: name,
        exerciseLogs: exerciseTemplates
            .map((e) => e.forLiveSessionFromTemplate())
            .toList(),
        startTime: DateTime.now(),
        endTime: DateTime.now());
  }

  RoutineTemplateDto copyWith({
    String? id,
    String? planId,
    String? name,
    String? notes,
    List<ExerciseLogDto>? exerciseTemplates,
    String? clientId,
    String? owner,
    int? planOrderIndex,
  }) {
    return RoutineTemplateDto(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      exerciseTemplates: exerciseTemplates != null
          ? exerciseTemplates.map((e) => e.copyWith()).toList()
          : this.exerciseTemplates.map((e) => e.copyWith()).toList(),
      clientId: clientId ?? this.clientId,
      owner: owner ?? this.owner,
      planOrderIndex: planOrderIndex ?? this.planOrderIndex,
    );
  }

  @override
  String toString() {
    return 'RoutineTemplateDto{id: $id, planId: $planId, name: $name, notes: $notes, exerciseTemplates: $exerciseTemplates}';
  }
}
