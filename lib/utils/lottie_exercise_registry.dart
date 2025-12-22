import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// Resolves exercise names to bundled Lottie animations using the explicit
/// mapping in assets/exercises/lottie_exercises.json.
class LottieExerciseRegistry {
  static Future<Map<String, String>>? _cache;

  static Future<Map<String, String>> _load() async {
    final raw =
        await rootBundle.loadString('assets/exercises/lottie_exercises.json');
    final data = jsonDecode(raw) as List<dynamic>;
    final map = <String, String>{};
    for (final entry in data) {
      if (entry is Map<String, dynamic>) {
        final name = (entry['name'] ?? '').toString().trim();
        final path = (entry['lottie'] ?? '').toString().trim();
        if (name.isNotEmpty && path.isNotEmpty) {
          map[name.toLowerCase()] = path;
        }
      }
    }
    return map;
  }

  /// Returns the lottie asset path for the given exercise [name] (case-insensitive),
  /// or null if none is available.
  static Future<String?> lottieFor(String name) async {
    _cache ??= _load();
    final map = await _cache!;
    return map[name.toLowerCase()];
  }
}

