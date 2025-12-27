import 'dart:convert';

import 'package:trainware/dtos/set_dtos/set_dto.dart';

import 'appsync/exercise_dto.dart';

class ExerciseLogDto {
  final String id;
  final String? routineLogId;
  final String superSetId;
  final ExerciseDto exercise;
  final String notes;
  final List<SetDto> sets;
  final DateTime createdAt;

  const ExerciseLogDto(
      {required this.id,
      required this.routineLogId,
      required this.superSetId,
      required this.exercise,
      required this.notes,
      required this.sets,
      required this.createdAt});

  Map<String, dynamic> toJson() {
    final setJsons = sets.map((set) => set.toJson()).toList();

    return {
      "superSetId": superSetId,
      "exercise": exercise.toJson(),
      "notes": notes,
      "sets": setJsons,
    };
  }

  ExerciseLogDto copyWith({
    String? id,
    String? routineLogId,
    String? superSetId,
    ExerciseDto? exercise,
    String? notes,
    List<SetDto>? sets,
    DateTime? createdAt,
  }) {
    return ExerciseLogDto(
      id: id ?? this.id,
      routineLogId: routineLogId ?? this.routineLogId,
      superSetId: superSetId ?? this.superSetId,

      // If a new ExerciseDto is provided, copy it deeply.
      // Otherwise, copy the existing ExerciseDto if it is not null.
      exercise:
          exercise != null ? exercise.copyWith() : this.exercise.copyWith(),
      notes: notes ?? this.notes,

      // Deep copy for the list of SetDto items.
      sets: sets != null
          ? sets.map((s) => s.copyWith()).toList()
          : this.sets.map((s) => s.copyWith()).toList(),

      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory ExerciseLogDto.fromJson(
      {String? routineLogId,
      DateTime? createdAt,
      required Map<String, dynamic> json}) {
    final superSetId = json["superSetId"] ?? "";
    final exerciseJson = json["exercise"];

    if (exerciseJson is! Map<String, dynamic>) {
      // Log offending payload to aid diagnosis.
      // ignore: avoid_print
      print('Invalid exercise entry payload: $json');
      throw const FormatException(
          'Invalid exercise entry: exercise must be an object');
    }
    final exercise = ExerciseDto.fromJson(exerciseJson);
    final notes = json["notes"] ?? "";
    final setsRaw = json["sets"];
    if (setsRaw is! List) {
      // ignore: avoid_print
      print('Invalid sets payload: $json');
      throw const FormatException(
          'Invalid exercise entry: sets must be provided as a list');
    }
    final setsInJsons = setsRaw;
    List<SetDto> sets = [];
    if (setsInJsons.isNotEmpty && setsInJsons.first is String) {
      sets = setsInJsons
          .map((json) => SetDto.fromJson(jsonDecode(json),
              exerciseType: exercise.type,
              datetime: createdAt ?? DateTime.now()))
          .toList();
    } else {
      sets = setsInJsons
          .map((json) => SetDto.fromJson(json,
              exerciseType: exercise.type,
              datetime: createdAt ?? DateTime.now()))
          .toList();
    }

    final exerciseLog = ExerciseLogDto(
        id: exercise.id,
        routineLogId: routineLogId,
        superSetId: superSetId,
        exercise: exercise,
        notes: notes,
        sets: sets,
        createdAt: createdAt ?? DateTime.now());

    return exerciseLog;
  }

  @override
  String toString() {
    return 'ExerciseLogDto{id: $id, routineLogId: $routineLogId, superSetId: $superSetId, exercise: $exercise, notes: $notes, sets: $sets, createdAt: $createdAt}';
  }
}
