import 'package:trainware/dtos/appsync/exercise_dto.dart';

/// Metadata wrapper around [ExerciseDto] for offline-first sync.
class ExerciseLocalEntry {
  final ExerciseDto exercise;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool needsSync;
  final bool lastSyncFailed;

  const ExerciseLocalEntry({
    required this.exercise,
    required this.updatedAt,
    required this.isDeleted,
    required this.needsSync,
    this.lastSyncFailed = false,
  });

  ExerciseLocalEntry copyWith({
    ExerciseDto? exercise,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? needsSync,
    bool? lastSyncFailed,
  }) {
    return ExerciseLocalEntry(
      exercise: exercise ?? this.exercise,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      needsSync: needsSync ?? this.needsSync,
      lastSyncFailed: lastSyncFailed ?? this.lastSyncFailed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exercise': exercise.toJson(),
      'updatedAt': updatedAt.toIso8601String(),
      'isDeleted': isDeleted,
      'needsSync': needsSync,
      'lastSyncFailed': lastSyncFailed,
    };
  }

  factory ExerciseLocalEntry.fromJson(Map<String, dynamic> json) {
    return ExerciseLocalEntry(
      exercise:
          ExerciseDto.fromJson(Map<String, dynamic>.from(json['exercise'])),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isDeleted: json['isDeleted'] as bool,
      needsSync: json['needsSync'] as bool,
      lastSyncFailed: json['lastSyncFailed'] as bool? ?? false,
    );
  }
}


