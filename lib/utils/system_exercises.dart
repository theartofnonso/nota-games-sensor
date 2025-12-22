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

/// Represents a seed exercise with lottie mapping and stable id.
class LottieExerciseSeed {
  final String id;
  final String name;
  final String muscleGroup;
  final String lottie;
  final bool isSystem;

  const LottieExerciseSeed({
    required this.id,
    required this.name,
    required this.muscleGroup,
    required this.lottie,
    this.isSystem = true,
  });

  factory LottieExerciseSeed.fromJson(Map<String, dynamic> json) {
    return LottieExerciseSeed(
      id: json['id'] as String,
      name: json['name'] as String,
      muscleGroup: json['muscleGroup'] as String,
      lottie: json['lottie'] as String,
      isSystem: json['isSystem'] == null ? true : json['isSystem'] as bool,
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

/// Load the bundled lottie-backed exercises from assets/exercises/lottie_exercises.json.
Future<List<LottieExerciseSeed>> loadLottieExercises() async {
  final raw =
      await rootBundle.loadString('assets/exercises/lottie_exercises.json');
  final data = jsonDecode(raw) as List<dynamic>;
  return data
      .map((e) => LottieExerciseSeed.fromJson(e as Map<String, dynamic>))
      .toList();
}

