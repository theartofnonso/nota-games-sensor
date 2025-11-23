import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../logger.dart';
import 'exercise_local_entry.dart';

/// File-based local persistence for user exercises.
///
/// We persist the entire list of entries as a single JSON file. Given the
/// expected number of custom exercises, this is a pragmatic approach.
class ExerciseLocalStore {
  static const _fileName = 'exercises_cache.json';

  final _logger = getLogger(className: 'ExerciseLocalStore');

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<ExerciseLocalEntry>> loadAll() async {
    try {
      final file = await _getFile();
      if (!await file.exists()) {
        return const [];
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return const [];
      }
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final items = decoded['items'] as List<dynamic>? ?? const [];
      return items
          .map((e) => ExerciseLocalEntry.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, stackTrace) {
      _logger.w('Failed to load local exercises: $e\n$stackTrace');
      return const [];
    }
  }

  Future<void> saveAll(List<ExerciseLocalEntry> entries) async {
    try {
      final file = await _getFile();
      final encoded = jsonEncode({
        'items': entries.map((e) => e.toJson()).toList(),
      });
      await file.writeAsString(encoded, flush: true);
    } catch (e, stackTrace) {
      _logger.w('Failed to save local exercises: $e\n$stackTrace');
    }
  }
}


