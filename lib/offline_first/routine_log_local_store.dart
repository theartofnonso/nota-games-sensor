import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../logger.dart';
import 'routine_log_local_entry.dart';

/// File-based local persistence for routine logs.
///
/// This is intentionally simple: we persist the entire list of entries
/// as a single JSON file. Given the expected size of workout history in
/// this app, this is a pragmatic solution without pulling in a full DB.
class RoutineLogLocalStore {
  static const _fileName = 'routine_logs_cache.json';

  final _logger = getLogger(className: 'RoutineLogLocalStore');

  Future<File> _getFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<List<RoutineLogLocalEntry>> loadAll() async {
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
          .map((e) => RoutineLogLocalEntry.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e, stackTrace) {
      _logger.w('Failed to load local routine logs: $e\n$stackTrace');
      return const [];
    }
  }

  Future<void> saveAll(List<RoutineLogLocalEntry> entries) async {
    try {
      final file = await _getFile();
      final encoded = jsonEncode({
        'items': entries.map((e) => e.toJson()).toList(),
      });
      await file.writeAsString(encoded, flush: true);
    } catch (e, stackTrace) {
      _logger.w('Failed to save local routine logs: $e\n$stackTrace');
    }
  }
}


