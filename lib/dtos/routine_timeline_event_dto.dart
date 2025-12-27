import 'package:uuid/uuid.dart';

class RoutineTimelineEventDto {
  final String id;
  final String logId;
  final String action;
  final DateTime timestamp;
  final String summary;
  final String? exerciseId;
  final String? exerciseName;
  final int? setIndex;
  final bool? checked;
  final Map<String, dynamic>? metadata;

  RoutineTimelineEventDto({
    String? id,
    required this.logId,
    required this.action,
    required this.timestamp,
    required this.summary,
    this.exerciseId,
    this.exerciseName,
    this.setIndex,
    this.checked,
    this.metadata,
  }) : id = id ?? const Uuid().v4();

  RoutineTimelineEventDto copyWith({
    String? id,
    String? logId,
    String? action,
    DateTime? timestamp,
    String? summary,
    String? exerciseId,
    String? exerciseName,
    int? setIndex,
    bool? checked,
    Map<String, dynamic>? metadata,
  }) {
    return RoutineTimelineEventDto(
      id: id ?? this.id,
      logId: logId ?? this.logId,
      action: action ?? this.action,
      timestamp: timestamp ?? this.timestamp,
      summary: summary ?? this.summary,
      exerciseId: exerciseId ?? this.exerciseId,
      exerciseName: exerciseName ?? this.exerciseName,
      setIndex: setIndex ?? this.setIndex,
      checked: checked ?? this.checked,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'logId': logId,
      'action': action,
      'timestamp': timestamp.toIso8601String(),
      'summary': summary,
      'exerciseId': exerciseId,
      'exerciseName': exerciseName,
      'setIndex': setIndex,
      'checked': checked,
      'metadata': metadata,
    };
  }

  factory RoutineTimelineEventDto.fromJson(Map<String, dynamic> json) {
    return RoutineTimelineEventDto(
      id: json['id'] as String?,
      logId: json['logId'] as String,
      action: json['action'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      summary: json['summary'] as String? ?? '',
      exerciseId: json['exerciseId'] as String?,
      exerciseName: json['exerciseName'] as String?,
      setIndex: json['setIndex'] as int?,
      checked: json['checked'] as bool?,
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>(),
    );
  }
}
