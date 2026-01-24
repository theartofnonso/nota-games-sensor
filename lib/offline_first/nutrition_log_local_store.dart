import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../logger.dart';
import 'nutrition_log_local_entry.dart';

class NutritionLogLocalStore {
  static const _fileName = 'nutrition_logs_cache.json';

  final _logger = getLogger(className: 'NutritionLogLocalStore');

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<NutritionLogLocalEntry>> loadAll() async {
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
          .map((e) => NutritionLogLocalEntry.fromJson(
              e as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      _logger.w('Failed to load local nutrition logs: $e\n$stackTrace');
      return const [];
    }
  }

  Future<void> saveAll(List<NutritionLogLocalEntry> entries) async {
    try {
      final file = await _getFile();
      final encoded = jsonEncode({
        'items': entries.map((e) => e.toJson()).toList(),
      });
      await file.writeAsString(encoded, flush: true);
    } catch (e, stackTrace) {
      _logger.w('Failed to save local nutrition logs: $e\n$stackTrace');
    }
  }

  Future<void> deleteAll() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
        _logger.i('Deleted nutrition logs cache file');
      }
    } catch (e, stackTrace) {
      _logger.w('Failed to delete local nutrition logs cache: $e\n$stackTrace');
    }
  }
}
