import 'package:trainware/dtos/appsync/routine_template_dto.dart';

/// Metadata wrapper around [RoutineTemplateDto] for offline-first sync.
class RoutineTemplateLocalEntry {
  final RoutineTemplateDto template;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool needsSync;
  final bool lastSyncFailed;

  const RoutineTemplateLocalEntry({
    required this.template,
    required this.updatedAt,
    required this.isDeleted,
    required this.needsSync,
    this.lastSyncFailed = false,
  });

  RoutineTemplateLocalEntry copyWith({
    RoutineTemplateDto? template,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? needsSync,
    bool? lastSyncFailed,
  }) {
    return RoutineTemplateLocalEntry(
      template: template ?? this.template,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      needsSync: needsSync ?? this.needsSync,
      lastSyncFailed: lastSyncFailed ?? this.lastSyncFailed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'template': template.toJson(),
      'updatedAt': updatedAt.toIso8601String(),
      'isDeleted': isDeleted,
      'needsSync': needsSync,
      'lastSyncFailed': lastSyncFailed,
    };
  }

  factory RoutineTemplateLocalEntry.fromJson(Map<String, dynamic> json) {
    return RoutineTemplateLocalEntry(
      template: RoutineTemplateDto.fromJson(
          json: Map<String, dynamic>.from(json['template'])),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isDeleted: json['isDeleted'] as bool? ?? false,
      needsSync: json['needsSync'] as bool? ?? false,
      lastSyncFailed: json['lastSyncFailed'] as bool? ?? false,
    );
  }
}


