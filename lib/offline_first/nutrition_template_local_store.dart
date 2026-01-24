import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../logger.dart';
import 'nutrition_template_local_entry.dart';

class NutritionTemplateLocalStore {
  static const _fileName = 'nutrition_templates_cache.json';

  final _logger = getLogger(className: 'NutritionTemplateLocalStore');

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<NutritionTemplateLocalEntry>> loadAll() async {
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
          .map((e) => NutritionTemplateLocalEntry.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList();
    } catch (e, stackTrace) {
      _logger.w('Failed to load local nutrition templates: $e\n$stackTrace');
      return const [];
    }
  }

  Future<void> saveAll(List<NutritionTemplateLocalEntry> entries) async {
    try {
      final file = await _getFile();
      final encoded = jsonEncode({
        'items': entries.map((e) => e.toJson()).toList(),
      });
      await file.writeAsString(encoded, flush: true);
    } catch (e, stackTrace) {
      _logger.w('Failed to save local nutrition templates: $e\n$stackTrace');
    }
  }

  Future<void> deleteAll() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
        _logger.i('Deleted nutrition templates cache file');
      }
    } catch (e, stackTrace) {
      _logger.w(
        'Failed to delete local nutrition templates cache: $e\n$stackTrace',
      );
    }
  }
}
