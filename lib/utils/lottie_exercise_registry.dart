import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart' show rootBundle;

/// Resolves exercise IDs to bundled Lottie animations using the explicit
/// mapping in assets/exercises/lottie_exercises.json.
/// Supports lookup by both ID and name for backward compatibility.
class LottieExerciseRegistry {
  static Future<Map<String, String>>? _cache;
  static final _rand = Random();

  static Future<Map<String, String>> _load() async {
    final raw =
        await rootBundle.loadString('assets/exercises/lottie_exercises.json');
    final data = jsonDecode(raw) as List<dynamic>;
    final map = <String, String>{};
    for (final entry in data) {
      if (entry is Map<String, dynamic>) {
        final id = (entry['id'] ?? '').toString().trim();
        final path = (entry['lottie'] ?? '').toString().trim();
        if (id.isNotEmpty && path.isNotEmpty) {
          map[id] = path; // Index by ID only
        }
      }
    }
    return map;
  }

  /// Returns the lottie asset path for the given exercise [id].
  /// The ID must match the exercise ID from lottie_exercises.json.
  /// Returns null if none is available.
  static Future<String?> lottieFor(String id) async {
    _cache ??= _load();
    final map = await _cache!;
    return map[id];
  }

  /// Returns a random lottie asset path from the registry (or null if empty).
  static Future<String?> randomLottie() async {
    _cache ??= _load();
    final map = await _cache!;
    if (map.isEmpty) return null;
    final values = map.values.toList(growable: false);
    return values[_rand.nextInt(values.length)];
  }
}
