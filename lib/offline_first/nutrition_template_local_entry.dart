import 'package:trainware/dtos/nutrition/nutrition_template_dto.dart';

class NutritionTemplateLocalEntry {
  final NutritionTemplateDto template;
  final DateTime updatedAt;
  final bool isDeleted;
  final bool needsSync;
  final bool lastSyncFailed;

  const NutritionTemplateLocalEntry({
    required this.template,
    required this.updatedAt,
    required this.isDeleted,
    required this.needsSync,
    this.lastSyncFailed = false,
  });

  NutritionTemplateLocalEntry copyWith({
    NutritionTemplateDto? template,
    DateTime? updatedAt,
    bool? isDeleted,
    bool? needsSync,
    bool? lastSyncFailed,
  }) {
    return NutritionTemplateLocalEntry(
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

  factory NutritionTemplateLocalEntry.fromJson(Map<String, dynamic> json) {
    return NutritionTemplateLocalEntry(
      template: NutritionTemplateDto.fromJson(
        json: Map<String, dynamic>.from(json['template']),
      ),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isDeleted: json['isDeleted'] as bool? ?? false,
      needsSync: json['needsSync'] as bool? ?? false,
      lastSyncFailed: json['lastSyncFailed'] as bool? ?? false,
    );
  }
}
