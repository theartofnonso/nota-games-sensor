import 'package:collection/collection.dart';
import 'package:tracker_app/dtos/set_dtos/weight_and_reps_dto.dart';
import 'package:tracker_app/enums/exercise_type_enums.dart';

import '../exercise_log_dto.dart';

class RoutineLogDto {
  final String id;
  final String templateId;
  final String name;
  final String notes;
  final DateTime startTime;
  final DateTime endTime;
  final List<ExerciseLogDto> exerciseLogs;

  RoutineLogDto({
    required this.id,
    required this.templateId,
    required this.name,
    required this.exerciseLogs,
    required this.notes,
    required this.startTime,
    required this.endTime,
  });

  Duration duration() {
    return endTime.difference(startTime);
  }

  Map<String, dynamic> toJson() {
    return {
      'templateId': templateId,
      'name': name,
      'notes': notes,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'exercises': exerciseLogs.map((exercise) => exercise.toJson()).toList(),
    };
  }

  factory RoutineLogDto.fromJson({required Map<String, dynamic> json}) {
    final id = json["id"] ?? "";
    final templateId = json["templateId"] ?? "";
    final name = json["name"] ?? "";
    final notes = json["notes"] ?? "";
    final startTime = DateTime.parse(json["startTime"]);
    final endTime = DateTime.parse(json["endTime"]);

    final exerciseLogJsons = json["exercises"] as List<dynamic>;
    final exerciseLogs = exerciseLogJsons.map((exerciseJson) {
      return ExerciseLogDto.fromJson(
        routineLogId: id,
        json: exerciseJson,
        createdAt: startTime,
      );
    }).toList();

    return RoutineLogDto(
      id: id,
      templateId: templateId,
      name: name,
      exerciseLogs: exerciseLogs,
      notes: notes,
      startTime: startTime,
      endTime: endTime,
    );
  }

  RoutineLogDto copyWith({
    String? id,
    String? templateId,
    String? name,
    String? notes,
    DateTime? startTime,
    DateTime? endTime,
    List<ExerciseLogDto>? exerciseLogs,
  }) {
    return RoutineLogDto(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      exerciseLogs: exerciseLogs != null
          ? exerciseLogs.map((e) => e.copyWith()).toList()
          : this.exerciseLogs.map((e) => e.copyWith()).toList(),
    );
  }

  @override
  String toString() {
    return 'RoutineLogDto{id: $id, templateId: $templateId, name: $name, notes: $notes, startTime: $startTime, endTime: $endTime, exerciseLogs: $exerciseLogs}';
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
