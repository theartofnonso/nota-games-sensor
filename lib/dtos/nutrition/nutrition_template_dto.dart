class NutritionTemplateDto {
  final String id;
  final String owner;
  final String clientId;
  final double calories;
  final double protein;
  final double carbs;
  final double fats;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NutritionTemplateDto({
    required this.id,
    required this.owner,
    required this.clientId,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner': owner,
      'client_id': clientId,
      'calories_kcal': calories,
      'protein_g': protein,
      'carbs_g': carbs,
      'fats_g': fats,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory NutritionTemplateDto.fromJson({required Map<String, dynamic> json}) {
    final proteinValue = json['protein_g'];
    final carbsValue = json['carbs_g'];
    final fatsValue = json['fats_g'];
    final caloriesValue = json['calories_kcal'];

    return NutritionTemplateDto(
      id: json['id'] as String? ?? '',
      owner: json['owner'] as String? ?? '',
      clientId: json['client_id'] as String? ?? '',
      calories: (caloriesValue as num?)?.toDouble() ?? 0,
      protein: (proteinValue as num?)?.toDouble() ?? 0,
      carbs: (carbsValue as num?)?.toDouble() ?? 0,
      fats: (fatsValue as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }
}
