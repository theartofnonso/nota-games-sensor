import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../logger.dart';
import 'routine_template_local_entry.dart';

/// File-based local persistence for routine templates.
class RoutineTemplateLocalStore {
  static const _fileName = 'routine_templates_cache.json';

  final _logger = getLogger(className: 'RoutineTemplateLocalStore');

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<RoutineTemplateLocalEntry>> loadAll() async {
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
          .map((e) => RoutineTemplateLocalEntry.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, stackTrace) {
      _logger.w('Failed to load local routine templates: $e\n$stackTrace');
      return const [];
    }
  }

  Future<void> saveAll(List<RoutineTemplateLocalEntry> entries) async {
    try {
      final file = await _getFile();
      final encoded = jsonEncode({
        'items': entries.map((e) => e.toJson()).toList(),
      });
      await file.writeAsString(encoded, flush: true);
    } catch (e, stackTrace) {
      _logger.w('Failed to save local routine templates: $e\n$stackTrace');
    }
  }
}


