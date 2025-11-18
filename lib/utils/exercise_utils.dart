import 'package:trainware/dtos/appsync/exercise_dto.dart';

/// Finds similar exercises using regex pattern matching
///
/// The regex matches exercises that:
/// - Have the same name (case-insensitive)
/// - Contain the search name as a substring (case-insensitive)
/// - Have similar spelling (within 1-2 character differences)
///
/// Returns a list of similar exercises, excluding the current exercise if provided.
List<ExerciseDto> findSimilarExercises({
  required String exerciseName,
  required List<ExerciseDto> allExercises,
  ExerciseDto? excludeExercise,
}) {
  if (exerciseName.trim().isEmpty) {
    return [];
  }

  final normalizedName = exerciseName.trim().toLowerCase();
  final similarExercises = <ExerciseDto>[];

  for (final exercise in allExercises) {
    // Skip the exercise being updated
    if (excludeExercise != null && exercise.id == excludeExercise.id) {
      continue;
    }

    final normalizedExerciseName = exercise.name.trim().toLowerCase();

    // Exact match (case-insensitive)
    if (normalizedExerciseName == normalizedName) {
      similarExercises.add(exercise);
      continue;
    }

    // Check if one name contains the other as substring
    if (normalizedExerciseName.contains(normalizedName) ||
        normalizedName.contains(normalizedExerciseName)) {
      similarExercises.add(exercise);
      continue;
    }

    // Use regex to find similar names
    // Create a pattern that allows for small variations
    // For example: "Bench Press" should match "Bench Presses" or "Benchpress"
    final words = normalizedName.split(RegExp(r'\s+'));
    if (words.length > 1) {
      // For multi-word names, check if all words are present
      final allWordsPresent = words.every(
          (word) => normalizedExerciseName.contains(word) || word.length <= 2);

      // Also check if exercise name contains significant words from the search
      final significantWords = words.where((w) => w.length > 2).toList();
      if (significantWords.isNotEmpty) {
        final significantWordsPresent = significantWords
            .every((word) => normalizedExerciseName.contains(word));

        if (significantWordsPresent && allWordsPresent) {
          similarExercises.add(exercise);
          continue;
        }
      }
    }

    // Check for Levenshtein-like similarity (simple character-based)
    // Count matching characters in sequence
    int matchingChars = 0;
    int minLength = normalizedName.length < normalizedExerciseName.length
        ? normalizedName.length
        : normalizedExerciseName.length;

    for (int i = 0; i < minLength; i++) {
      if (normalizedName[i] == normalizedExerciseName[i]) {
        matchingChars++;
      }
    }

    // If more than 70% of characters match in sequence, consider it similar
    if (minLength > 0 && (matchingChars / minLength) > 0.7) {
      // Additional check: the length difference shouldn't be too large
      final lengthDiff =
          (normalizedName.length - normalizedExerciseName.length).abs();
      if (lengthDiff <= 3) {
        similarExercises.add(exercise);
      }
    }
  }

  // Remove duplicates and return
  final seen = <String>{};
  return similarExercises.where((exercise) {
    if (seen.contains(exercise.id)) {
      return false;
    }
    seen.add(exercise.id);
    return true;
  }).toList();
}
