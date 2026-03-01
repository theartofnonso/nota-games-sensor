import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../urls.dart';
import '../utils/notathletes_auth_headers.dart';

/// Response from the exercise instruction API.
class ExerciseInstruction {
  final String name;
  final List<String>? setup;
  final List<String>? movement;
  final String? feel;
  final List<String>? avoid;
  final String? proTip;
  final List<String>? regression;
  final List<String>? progression;
  final String? difficulty;

  const ExerciseInstruction({
    required this.name,
    this.setup,
    this.movement,
    this.feel,
    this.avoid,
    this.proTip,
    this.regression,
    this.progression,
    this.difficulty,
  });
}

/// In-memory cache during the session. Cleared when app restarts.
final _instructionCache = <String, ExerciseInstruction>{};

/// Calls openai.notathletes.com for exercise instructions.
/// Results are cached in memory for the session to avoid repeated requests.
Future<ExerciseInstruction?> fetchExerciseInstruction(String exerciseName) async {
  final trimmed = exerciseName.trim();
  if (trimmed.isEmpty) return null;

  final cacheKey = trimmed.toLowerCase();
  final cached = _instructionCache[cacheKey];
  if (cached != null) return cached;

  final uri = Uri.parse(openAiBaseUrl).resolve(exerciseInstructionPath);
  try {
    final response = await http.post(
      uri,
      headers: notathletesAuthHeaders(),
      body: jsonEncode({'exercise': trimmed}),
    ).timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      debugPrint(
          '[ExerciseInstruction] API error ${response.statusCode}: ${response.body}');
      return null;
    }

    final data = jsonDecode(response.body);
    if (data is! Map<String, dynamic>) return null;

    final name = data['name'] as String? ?? trimmed;
    final setup = _parseStringList(data['setup']);
    final movement = _parseStringList(data['movement']);
    final feel = (data['feel'] as String?)?.trim();
    final avoid = _parseStringList(data['avoid']);
    final proTip = (data['pro_tip'] as String?)?.trim();
    final regression = _parseStringList(data['regression']);
    final progression = _parseStringList(data['progression']);
    final difficulty = (data['difficulty'] as String?)?.trim();

    final instruction = ExerciseInstruction(
      name: name,
      setup: setup,
      movement: movement,
      feel: feel,
      avoid: avoid,
      proTip: proTip,
      regression: regression,
      progression: progression,
      difficulty: difficulty,
    );
    _instructionCache[cacheKey] = instruction;
    return instruction;
  } catch (e) {
    debugPrint('[ExerciseInstruction] Request failed: $e');
    return null;
  }
}

List<String>? _parseStringList(dynamic value) {
  if (value == null) return null;
  if (value is! List) return null;
  final list = value
      .map((e) => (e is String ? e.trim() : e?.toString().trim()) ?? '')
      .where((s) => s.isNotEmpty)
      .toList();
  return list.isEmpty ? null : list;
}
