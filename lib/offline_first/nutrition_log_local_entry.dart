import 'package:trainware/dtos/nutrition/nutrition_log_dto.dart';

class NutritionLogLocalEntry {
  final NutritionLogDto log;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool needsSync;
  final bool lastSyncFailed;

  const NutritionLogLocalEntry({
    required this.log,
    required this.updatedAt,
    required this.isDeleted,
    required this.needsSync,
    this.lastSyncFailed = false,
  });

  NutritionLogLocalEntry copyWith({
    NutritionLogDto? log,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? needsSync,
    bool? lastSyncFailed,
  }) {
    return NutritionLogLocalEntry(
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

  factory NutritionLogLocalEntry.fromJson(Map<String, dynamic> json) {
    return NutritionLogLocalEntry(
      log: NutritionLogDto.fromJson(
        json: Map<String, dynamic>.from(json['log']),
      ),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isDeleted: json['isDeleted'] as bool? ?? false,
      needsSync: json['needsSync'] as bool? ?? false,
      lastSyncFailed: json['lastSyncFailed'] as bool? ?? false,
    );
  }
}
