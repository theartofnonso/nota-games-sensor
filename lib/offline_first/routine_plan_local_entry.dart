import 'package:trainware/dtos/appsync/routine_plan_dto.dart';

/// Metadata wrapper around [RoutinePlanDto] for offline-first sync.
class RoutinePlanLocalEntry {
  final RoutinePlanDto plan;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool needsSync;
  final bool lastSyncFailed;

  const RoutinePlanLocalEntry({
    required this.plan,
    required this.updatedAt,
    required this.isDeleted,
    required this.needsSync,
    this.lastSyncFailed = false,
  });

  RoutinePlanLocalEntry copyWith({
    RoutinePlanDto? plan,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? needsSync,
    bool? lastSyncFailed,
  }) {
    return RoutinePlanLocalEntry(
      plan: plan ?? this.plan,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      needsSync: needsSync ?? this.needsSync,
      lastSyncFailed: lastSyncFailed ?? this.lastSyncFailed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'plan': plan.toJson(),
      'updatedAt': updatedAt.toIso8601String(),
      'isDeleted': isDeleted,
      'needsSync': needsSync,
      'lastSyncFailed': lastSyncFailed,
    };
  }

  factory RoutinePlanLocalEntry.fromJson(Map<String, dynamic> json) {
    return RoutinePlanLocalEntry(
      plan: RoutinePlanDto.fromJson(json: Map<String, dynamic>.from(json['plan'])),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isDeleted: json['isDeleted'] as bool? ?? false,
      needsSync: json['needsSync'] as bool? ?? false,
      lastSyncFailed: json['lastSyncFailed'] as bool? ?? false,
    );
  }
}


