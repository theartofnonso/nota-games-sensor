import 'package:trainware/dtos/appsync/routine_log_dto.dart';

/// Simple metadata wrapper around [RoutineLogDto] for offline-first sync.
///
/// We intentionally keep sync metadata out of the core DTO so the rest of
/// the app can continue using [RoutineLogDto] unchanged.
class RoutineLogLocalEntry {
  final RoutineLogDto log;

  /// When this record was last modified locally or by the server.
  ///
  /// For remote data, this should come from the Supabase `updatedAt` column.
  /// For local-only changes, we set it to `DateTime.now()`.
  final DateTime updatedAt;

  /// Whether this log has been deleted locally but not yet removed remotely.
  final bool isDeleted;

  /// Whether this entry has local changes that still need to be synced
  /// to the server.
  final bool needsSync;

  /// Whether the last attempt to sync this entry to the server failed.
  /// This allows the UI to surface a more explicit "failed" state instead
  /// of treating everything as just "pending".
  final bool lastSyncFailed;

  const RoutineLogLocalEntry({
    required this.log,
    required this.updatedAt,
    required this.isDeleted,
    required this.needsSync,
    this.lastSyncFailed = false,
  });

  RoutineLogLocalEntry copyWith({
    RoutineLogDto? log,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? needsSync,
    bool? lastSyncFailed,
  }) {
    return RoutineLogLocalEntry(
      log: log ?? this.log,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      needsSync: needsSync ?? this.needsSync,
      lastSyncFailed: lastSyncFailed ?? this.lastSyncFailed,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'log': log.toJson(),
      'updatedAt': updatedAt.toIso8601String(),
      'isDeleted': isDeleted,
      'needsSync': needsSync,
      'lastSyncFailed': lastSyncFailed,
    };
  }

  factory RoutineLogLocalEntry.fromJson(Map<String, dynamic> json) {
    return RoutineLogLocalEntry(
      log: RoutineLogDto.fromJson(json: json['log'] as Map<String, dynamic>),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isDeleted: json['isDeleted'] as bool? ?? false,
      needsSync: json['needsSync'] as bool? ?? false,
      lastSyncFailed: json['lastSyncFailed'] as bool? ?? false,
    );
  }
}
