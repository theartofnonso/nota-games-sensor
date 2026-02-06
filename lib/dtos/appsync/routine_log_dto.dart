import 'package:collection/collection.dart';
import 'package:trainware/dtos/set_dtos/weight_and_reps_dto.dart';
import 'package:trainware/enums/exercise_type_enums.dart';

import '../exercise_log_dto.dart';

class RoutineLogDto {
  final String id;
  final String templateId;
  final String name;
  final DateTime startTime;
  final DateTime endTime;
  final List<ExerciseLogDto> exerciseLogs;
  /// Single note from the coach for this session. Coaches can add/edit; clients read-only.
  final String? coachNote;

  RoutineLogDto({
    required this.id,
    required this.templateId,
    required this.name,
    required this.exerciseLogs,
    required this.startTime,
    required this.endTime,
    this.coachNote,
  });

  Duration duration() {
    return endTime.difference(startTime);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'templateId': templateId,
      'name': name,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'exercises': exerciseLogs.map((exercise) => exercise.toJson()).toList(),
      'coach_note': coachNote,
    };
  }

  factory RoutineLogDto.fromJson({required Map<String, dynamic> json}) {
    final id = json["id"] as String? ?? "";
    final templateId = json["templateId"] as String? ?? "";
    final name = json["name"] as String;
    final startTime = DateTime.parse(json["startTime"] as String);
    final endTime = DateTime.parse(json["endTime"] as String);
    final coachNote = json["coach_note"] as String?;

    final exerciseLogJsons = json["exercises"] as List;
    final exerciseLogs = exerciseLogJsons
        .map((exerciseJson) => ExerciseLogDto.fromJson(
              routineLogId: id,
              json: exerciseJson as Map<String, dynamic>,
              createdAt: startTime,
            ))
        .toList();

    return RoutineLogDto(
      id: id,
      templateId: templateId,
      name: name,
      exerciseLogs: exerciseLogs,
      startTime: startTime,
      endTime: endTime,
      coachNote: coachNote != null && coachNote.trim().isNotEmpty ? coachNote : null,
    );
  }

  RoutineLogDto copyWith({
    String? id,
    String? templateId,
    String? name,
    DateTime? startTime,
    DateTime? endTime,
    List<ExerciseLogDto>? exerciseLogs,
    String? coachNote,
  }) {
    return RoutineLogDto(
      id: id ?? this.id,
      templateId: templateId ?? this.templateId,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      exerciseLogs: exerciseLogs != null
          ? exerciseLogs.map((e) => e.copyWith()).toList()
          : this.exerciseLogs.map((e) => e.copyWith()).toList(),
      coachNote: coachNote ?? this.coachNote,
    );
  }

  @override
  String toString() {
    return 'RoutineLogDto{id: $id, templateId: $templateId, name: $name, startTime: $startTime, endTime: $endTime, exerciseLogs: $exerciseLogs}';
  }

  double get volume =>
      exerciseLogs.expand((exerciseLog) => exerciseLog.sets).map((set) {
        return switch (set.type) {
          ExerciseType.weights => (set as WeightAndRepsSetDto).volume(),
          ExerciseType.bodyWeight => 0.0,
          ExerciseType.duration => 0.0,
          ExerciseType.none => 0.0,
        };
      }).sum;
}
