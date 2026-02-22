import 'package:flutter/material.dart';
import 'package:trainware/enums/exercise_type_enums.dart';

enum ExerciseChallengeTargetType {
  weight('weight'),
  reps('reps'),
  duration('duration');

  const ExerciseChallengeTargetType(this.id);
  final String id;

  static ExerciseChallengeTargetType fromString(String raw) {
    final value = raw.trim().toLowerCase();
    return ExerciseChallengeTargetType.values.firstWhere(
      (t) => t.id == value,
      orElse: () => ExerciseChallengeTargetType.reps,
    );
  }
}

enum ExerciseChallengeStatus {
  upcoming,
  active,
  completed,
  expired,
}

class ExerciseChallengeDto {
  final String id;
  final String coachId;
  final String clientId;
  final String title;
  final String templateId;
  final String templateExerciseId;
  final String exerciseId;
  final String exerciseName;
  final ExerciseType exerciseType;
  final double? targetWeight;
  final int? targetReps;
  final int? targetDurationSeconds;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;

  const ExerciseChallengeDto({
    required this.id,
    required this.coachId,
    required this.clientId,
    required this.title,
    required this.templateId,
    required this.templateExerciseId,
    required this.exerciseId,
    required this.exerciseName,
    required this.exerciseType,
    required this.targetWeight,
    required this.targetReps,
    required this.targetDurationSeconds,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
  });

  factory ExerciseChallengeDto.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic raw) {
      final parsed = DateTime.tryParse(raw?.toString() ?? '');
      return parsed ?? DateTime.now();
    }

    return ExerciseChallengeDto(
      id: json['id']?.toString() ?? '',
      coachId: json['coach_id']?.toString() ?? '',
      clientId: json['client_id']?.toString() ?? '',
      title: json['title']?.toString().trim() ?? '',
      templateId: json['template_id']?.toString() ?? '',
      templateExerciseId: json['template_exercise_id']?.toString() ?? '',
      exerciseId: json['exercise_id']?.toString() ?? '',
      exerciseName: json['exercise_name']?.toString() ?? 'Exercise',
      exerciseType: ExerciseType.fromString(json['exercise_type']?.toString() ?? 'NO'),
      targetWeight: (json['target_weight'] as num?)?.toDouble(),
      targetReps: (json['target_reps'] as num?)?.toInt(),
      targetDurationSeconds: (json['target_duration_seconds'] as num?)?.toInt(),
      startDate: DateUtils.dateOnly(parseDate(json['start_date'])),
      endDate: DateUtils.dateOnly(parseDate(json['end_date'])),
      createdAt: parseDate(json['created_at']),
    );
  }

  Map<String, dynamic> toInsertJson() {
    return {
      'coach_id': coachId,
      'client_id': clientId,
      'title': title,
      'template_id': templateId,
      'template_exercise_id': templateExerciseId,
      'exercise_id': exerciseId,
      'exercise_name': exerciseName,
      'exercise_type': exerciseType.id,
      // Keep legacy fields populated for compatibility while backend migrates.
      'target_type': targetType.id,
      'target_value': targetValue,
      'target_weight': targetWeight,
      'target_reps': targetReps,
      'target_duration_seconds': targetDurationSeconds,
      'start_date': DateUtils.dateOnly(startDate).toIso8601String(),
      'end_date': DateUtils.dateOnly(endDate).toIso8601String(),
    };
  }

  ExerciseChallengeTargetType get targetType {
    switch (exerciseType) {
      case ExerciseType.weights:
        return ExerciseChallengeTargetType.weight;
      case ExerciseType.bodyWeight:
        return ExerciseChallengeTargetType.reps;
      case ExerciseType.duration:
        return ExerciseChallengeTargetType.duration;
      case ExerciseType.none:
        return ExerciseChallengeTargetType.reps;
    }
  }

  double get targetValue {
    switch (exerciseType) {
      case ExerciseType.weights:
        return targetWeight ?? 0;
      case ExerciseType.bodyWeight:
        return (targetReps ?? 0).toDouble();
      case ExerciseType.duration:
        return (targetDurationSeconds ?? 0).toDouble();
      case ExerciseType.none:
        return 0;
    }
  }
}

class ExerciseChallengeProgress {
  final double bestValue;
  final double targetValue;
  final double? bestWeight;
  final int? bestReps;
  final int? bestDurationSeconds;
  final double? targetWeight;
  final int? targetReps;
  final int? targetDurationSeconds;
  final double percent; // 0..1
  final bool achieved;
  final ExerciseChallengeStatus status;

  const ExerciseChallengeProgress({
    required this.bestValue,
    required this.targetValue,
    this.bestWeight,
    this.bestReps,
    this.bestDurationSeconds,
    this.targetWeight,
    this.targetReps,
    this.targetDurationSeconds,
    required this.percent,
    required this.achieved,
    required this.status,
  });
}
