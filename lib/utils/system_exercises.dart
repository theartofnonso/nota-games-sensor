import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Represents a seed exercise definition. Keep this minimal and equipment-free.
class SystemExerciseSeed {
  final String name;
  final String muscleGroup;

  const SystemExerciseSeed({required this.name, required this.muscleGroup});

  factory SystemExerciseSeed.fromJson(Map<String, dynamic> json) {
    return SystemExerciseSeed(
      name: json['name'] as String,
      muscleGroup: json['muscleGroup'] as String,
    );
  }
}

/// Load the bundled system exercises from assets/exercises/system_exercises.json.
/// This keeps the canonical list in one place for seeding/merging into storage.
Future<List<SystemExerciseSeed>> loadSystemExercises() async {
  final raw =
      await rootBundle.loadString('assets/exercises/system_exercises.json');
  final data = jsonDecode(raw) as List<dynamic>;
  return data
      .map((e) => SystemExerciseSeed.fromJson(e as Map<String, dynamic>))
      .toList();
}

