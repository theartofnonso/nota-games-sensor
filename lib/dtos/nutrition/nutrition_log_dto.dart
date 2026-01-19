class NutritionLogDto {
  final String id;
  final String userId;
  final String foodName;
  final double protein;
  final double carbs;
  final double fats;
  final DateTime loggedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  NutritionLogDto({
    required this.id,
    required this.userId,
    required this.foodName,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.loggedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  double get calories => (protein * 4) + (carbs * 4) + (fats * 9);
  int get caloriesRounded => calories.round();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'food_name': foodName,
      'protein_g': protein,
      'carbs_g': carbs,
      'fats_g': fats,
      'logged_at': loggedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory NutritionLogDto.fromJson({required Map<String, dynamic> json}) {
    final proteinValue = json['protein_g'];
    final carbsValue = json['carbs_g'];
    final fatsValue = json['fats_g'];

    return NutritionLogDto(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      foodName: json['food_name'] as String? ?? '',
      protein: (proteinValue as num?)?.toDouble() ?? 0,
      carbs: (carbsValue as num?)?.toDouble() ?? 0,
      fats: (fatsValue as num?)?.toDouble() ?? 0,
      loggedAt: DateTime.parse(json['logged_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  NutritionLogDto copyWith({
    String? id,
    String? userId,
    String? foodName,
    double? protein,
    double? carbs,
    double? fats,
    DateTime? loggedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return NutritionLogDto(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      foodName: foodName ?? this.foodName,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fats: fats ?? this.fats,
      loggedAt: loggedAt ?? this.loggedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
