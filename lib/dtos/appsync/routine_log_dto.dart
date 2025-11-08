import 'package:collection/collection.dart';
import 'package:tracker_app/dtos/set_dtos/weight_and_reps_dto.dart';
import 'package:tracker_app/enums/exercise_type_enums.dart';

import '../exercise_log_dto.dart';

class RoutineLogDto {
  final String id;
  final String templateId;
  final String name;
  final String notes;
  final String? summary;
  final DateTime startTime;
  final DateTime endTime;
  final List<ExerciseLogDto> exerciseLogs;
  final String owner;
  final DateTime createdAt;
  final DateTime updatedAt;

  RoutineLogDto({
    required this.id,
    required this.templateId,
    required this.name,
    required this.exerciseLogs,
    required this.notes,
    this.summary,
    required this.startTime,
    required this.endTime,
    required this.owner,
    required this.createdAt,
    required this.updatedAt,
  });

  Duration duration() {
    return endTime.difference(startTime);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'templateId': templateId,
      'name': name,
      'notes': notes,
      'summary': summary,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'exercises': exerciseLogs.map((exercise) => exercise.toJson()).toList(),
      'owner': owner,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory RoutineLogDto.fromJson({required Map<String, dynamic> json}) {
    final id = json["id"] ?? "";
    final templateId = json["templateId"] ?? "";
    final name = json["name"] ?? "";
    final notes = json["notes"] ?? "";
    final summary = json["summary"];
    final startTime = DateTime.parse(json["startTime"]);
    final endTime = DateTime.parse(json["endTime"]);
    final owner = json["owner"] ?? "";
    final createdAt = json["createdAt"] != null ? DateTime.parse(json["createdAt"]) : DateTime.now();
    final updatedAt = json["updatedAt"] != null ? DateTime.parse(json["updatedAt"]) : DateTime.now();
    
    final exerciseLogJsons = json["exercises"] as List<dynamic>;
    final exerciseLogs = exerciseLogJsons.map((exerciseJson) {
      return ExerciseLogDto.fromJson(
        routineLogId: id,
        json: exerciseJson,
        createdAt: createdAt,
      );
    }).toList();
    
    return RoutineLogDto(
      id: id,
      templateId: templateId,
      name: name,
      exerciseLogs: exerciseLogs,
      notes: notes,
      summary: summary,
      startTime: startTime,
      endTime: endTime,
      owner: owner,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  RoutineLogDto copyWith({
    String? id,
    String? templateId,
    String? name,
    String? notes,
    String? summary,
    DateTime? startTime,
    DateTime? endTime,
    List<ExerciseLogDto>? exerciseLogs,
    String? owner,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return RoutineLogDto(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      summary: summary ?? this.summary,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      exerciseLogs: exerciseLogs != null
          ? exerciseLogs.map((e) => e.copyWith()).toList()
          : this.exerciseLogs.map((e) => e.copyWith()).toList(),
      owner: owner ?? this.owner,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'RoutineLogDto{id: $id, templateId: $templateId, name: $name, notes: $notes, summary: $summary, startTime: $startTime, endTime: $endTime, exerciseLogs: $exerciseLogs, owner: $owner, createdAt: $createdAt, updatedAt: $updatedAt}';
  }

  double get volume =>
      exerciseLogs.expand((exerciseLog) => exerciseLog.sets).map((set) {
        return switch (set.type) {
          ExerciseType.weights => (set as WeightAndRepsSetDto).volume(),
          ExerciseType.bodyWeight => 0.0,
          ExerciseType.duration => 0.0,
        };
      }).sum;
}
