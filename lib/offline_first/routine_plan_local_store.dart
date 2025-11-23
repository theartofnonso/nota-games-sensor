import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../logger.dart';
import 'routine_plan_local_entry.dart';

/// File-based local persistence for routine plans.
class RoutinePlanLocalStore {
  static const _fileName = 'routine_plans_cache.json';

  final _logger = getLogger(className: 'RoutinePlanLocalStore');

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<RoutinePlanLocalEntry>> loadAll() async {
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
          .map((e) => RoutinePlanLocalEntry.fromJson(
              Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (e, stackTrace) {
      _logger.w('Failed to load local routine plans: $e\n$stackTrace');
      return const [];
    }
  }

  Future<void> saveAll(List<RoutinePlanLocalEntry> entries) async {
    try {
      final file = await _getFile();
      final encoded = jsonEncode({
        'items': entries.map((e) => e.toJson()).toList(),
      });
      await file.writeAsString(encoded, flush: true);
    } catch (e, stackTrace) {
      _logger.w('Failed to save local routine plans: $e\n$stackTrace');
    }
  }
}


