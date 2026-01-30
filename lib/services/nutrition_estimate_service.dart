import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../urls.dart';

/// Response from the nutrition estimate API.
class NutritionEstimate {
  final double calories;
  final double protein;
  final double carbs;
  final double fats;

  const NutritionEstimate({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
  });
}

/// Calls openai.notathletes.com to estimate macros from a meal description.
/// Request: POST /api, body { "meal": "string" }.
/// Response: { "calories", "protein", "carbs", "fats" } (numeric).
Future<NutritionEstimate?> estimateFromMealDescription(String meal) async {
  final trimmed = meal.trim();
  if (trimmed.isEmpty) return null;

  final uri =
      Uri.parse(nutritionEstimateBaseUrl).resolve(nutritionEstimatePath);
  try {
    final response = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'meal': trimmed}),
    );

    if (response.statusCode != 200) {
      debugPrint(
          '[NutritionEstimate] API error ${response.statusCode}: ${response.body}');
      return null;
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) return null;

    final calories = (data['calories'] as num?)?.toDouble();
    final protein = (data['protein'] as num?)?.toDouble();
    final carbs = (data['carbs'] as num?)?.toDouble();
    final fats = (data['fats'] as num?)?.toDouble();

    if (calories == null || protein == null || carbs == null || fats == null) {
      debugPrint('[NutritionEstimate] Missing fields in response: $data');
      return null;
    }

    return NutritionEstimate(
      calories: calories,
      protein: protein,
      carbs: carbs,
      fats: fats,
    );
  } catch (e) {
    debugPrint('[NutritionEstimate] Request failed: $e');
    return null;
  }
}
