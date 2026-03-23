import 'dart:convert';

import 'package:trainware/dtos/set_dtos/set_dto.dart';
import 'package:trainware/enums/exercise_type_enums.dart';

import 'appsync/exercise_dto.dart';

class ExerciseLogDto {
  final String id;
  final String? routineLogId;
  final String superSetId;
  final ExerciseDto exercise;
  final String notes;
  final List<SetDto> sets;
  final List<ExerciseDto> alternatives;
  final DateTime createdAt;

  /// Supabase `session_exercises.id` when loaded from a saved workout session.
  final String? sessionExerciseId;

  /// Supabase `template_exercises.id` when loaded from a saved routine template.
  final String? templateExerciseId;

  /// Storage path in the `coach-instruction-videos` bucket (coach-only writes).
  final String? coachInstructionVideoPath;

  const ExerciseLogDto(
      {required this.id,
      required this.routineLogId,
      required this.superSetId,
      required this.exercise,
      required this.notes,
      required this.sets,
      this.alternatives = const [],
      required this.createdAt,
      this.sessionExerciseId,
      this.templateExerciseId,
      this.coachInstructionVideoPath});

  Map<String, dynamic> toJson() {
    final setJsons = sets.map((set) => set.toJson()).toList();
    final alternativeJsons = alternatives.map((alt) => alt.toJson()).toList();

    return {
      "superSetId": superSetId,
      "exercise": exercise.toJson(),
      "notes": notes,
      "sets": setJsons,
      "alternatives": alternativeJsons,
      if (sessionExerciseId != null) "sessionExerciseId": sessionExerciseId,
      if (templateExerciseId != null) "templateExerciseId": templateExerciseId,
      if (coachInstructionVideoPath != null)
        "coachInstructionVideoPath": coachInstructionVideoPath,
    };
  }

  ExerciseLogDto copyWith({
    String? id,
    String? routineLogId,
    String? superSetId,
    ExerciseDto? exercise,
    String? notes,
    List<SetDto>? sets,
    List<ExerciseDto>? alternatives,
    DateTime? createdAt,
    String? sessionExerciseId,
    String? templateExerciseId,
    String? coachInstructionVideoPath,
    bool clearCoachInstructionVideo = false,
    bool wipeSessionExerciseFields = false,
    bool wipeTemplateExerciseFields = false,
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

      // Deep copy for the list of alternative exercises.
      alternatives: alternatives ?? this.alternatives.map((alt) => alt.copyWith()).toList(),

      createdAt: createdAt ?? this.createdAt,
      sessionExerciseId: wipeSessionExerciseFields
          ? null
          : (sessionExerciseId ?? this.sessionExerciseId),
      templateExerciseId: wipeSessionExerciseFields || wipeTemplateExerciseFields
          ? null
          : (templateExerciseId ?? this.templateExerciseId),
      coachInstructionVideoPath: wipeSessionExerciseFields ||
              wipeTemplateExerciseFields ||
              clearCoachInstructionVideo
          ? null
          : (coachInstructionVideoPath ?? this.coachInstructionVideoPath),
    );
  }

  /// New live session from template: keep template row id + video path in memory (from template).
  /// Video is not written to session_exercises; [templateExerciseId] links the saved session line to the template row.
  ExerciseLogDto forLiveSessionFromTemplate() {
    return ExerciseLogDto(
      id: id,
      routineLogId: '',
      superSetId: superSetId,
      exercise: exercise.copyWith(),
      notes: notes,
      sets: sets.map((s) => s.copyWith()).toList(),
      alternatives: alternatives.map((a) => a.copyWith()).toList(),
      createdAt: createdAt,
      sessionExerciseId: null,
      templateExerciseId: templateExerciseId,
      coachInstructionVideoPath: coachInstructionVideoPath,
    );
  }

  factory ExerciseLogDto.fromJson(
      {String? routineLogId,
      DateTime? createdAt,
      required Map<String, dynamic> json}) {
    final superSetId = json["superSetId"] as String? ?? "";
    final exerciseJson = json["exercise"] as Map<String, dynamic>;
    final exercise = ExerciseDto.fromJson(exerciseJson);

    if (exercise.type == ExerciseType.none) {
      throw const FormatException(
          'Exercise type must be selected for exercises in logs/templates');
    }

    final notes = json["notes"] as String? ?? "";
    final setsRaw = json["sets"] as List;
    final sets = setsRaw
        .map((setJson) => SetDto.fromJson(
            setJson is String ? jsonDecode(setJson) : setJson,
            exerciseType: exercise.type,
            datetime: createdAt ?? DateTime.now()))
        .toList();

    final alternativesRaw = json["alternatives"] as List? ?? [];
    final alternatives = alternativesRaw
        .map((altJson) => ExerciseDto.fromJson(
            altJson is String ? jsonDecode(altJson) : altJson as Map<String, dynamic>))
        .toList();

    final sessionExerciseId = json["sessionExerciseId"] as String?;
    final templateExerciseId = json["templateExerciseId"] as String?;
    final path = json["coachInstructionVideoPath"] as String?;
    final coachInstructionVideoPath =
        path != null && path.trim().isNotEmpty ? path.trim() : null;

    return ExerciseLogDto(
        id: exercise.id,
        routineLogId: routineLogId,
        superSetId: superSetId,
        exercise: exercise,
        notes: notes,
        sets: sets,
        alternatives: alternatives,
        createdAt: createdAt ?? DateTime.now(),
        sessionExerciseId: sessionExerciseId,
        templateExerciseId: templateExerciseId,
        coachInstructionVideoPath: coachInstructionVideoPath);
  }

  @override
  String toString() {
    return 'ExerciseLogDto{id: $id, routineLogId: $routineLogId, superSetId: $superSetId, exercise: $exercise, notes: $notes, sets: $sets, createdAt: $createdAt}';
  }
}
