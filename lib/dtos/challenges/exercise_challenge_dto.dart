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
  final String exerciseId;
  final String exerciseName;
  final ExerciseType exerciseType;
  final ExerciseChallengeTargetType targetType;
  final double targetValue;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;

  const ExerciseChallengeDto({
    required this.id,
    required this.coachId,
    required this.clientId,
    required this.title,
    required this.exerciseId,
    required this.exerciseName,
    required this.exerciseType,
    required this.targetType,
    required this.targetValue,
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
      exerciseId: json['exercise_id']?.toString() ?? '',
      exerciseName: json['exercise_name']?.toString() ?? 'Exercise',
      exerciseType: ExerciseType.fromString(json['exercise_type']?.toString() ?? 'NO'),
      targetType: ExerciseChallengeTargetType.fromString(
        json['target_type']?.toString() ?? 'reps',
      ),
      targetValue: (json['target_value'] as num?)?.toDouble() ?? 0,
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
      'exercise_id': exerciseId,
      'exercise_name': exerciseName,
      'exercise_type': exerciseType.id,
      'target_type': targetType.id,
      'target_value': targetValue,
      'start_date': DateUtils.dateOnly(startDate).toIso8601String(),
      'end_date': DateUtils.dateOnly(endDate).toIso8601String(),
    };
  }
}

class ExerciseChallengeProgress {
  final double bestValue;
  final double targetValue;
  final double percent; // 0..1
  final bool achieved;
  final ExerciseChallengeStatus status;

  const ExerciseChallengeProgress({
    required this.bestValue,
    required this.targetValue,
    required this.percent,
    required this.achieved,
    required this.status,
  });
}
