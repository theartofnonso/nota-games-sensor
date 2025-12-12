import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';
import 'package:trainware/dtos/shareable_routine_summary.dart';

import 'shareable_routine_renderer.dart';

class RoutineShareService {
  RoutineShareService({ShareableRoutineRenderer? renderer})
      : renderer = renderer ?? ShareableRoutineRenderer();

  final ShareableRoutineRenderer renderer;
  final Map<String, XFile> _cache = {};

  String _cacheKey(RoutineLogDto log) =>
      "${log.id}-${log.endTime.millisecondsSinceEpoch}";

  Future<void> shareRoutineLog({
    required BuildContext context,
    required RoutineLogDto log,
  }) async {
    final summary = ShareableRoutineSummary.fromRoutineLog(log);
    final file =
        await ensureCached(context: context, log: log, summary: summary);

    await Share.shareXFiles(
      [file],
      text: "Workout summary — ${summary.routineName}",
    );
  }

  Future<XFile> ensureCached({
    required BuildContext context,
    required RoutineLogDto log,
    ShareableRoutineSummary? summary,
  }) async {
    final key = _cacheKey(log);
    final cached = _cache[key];
    if (cached != null) return cached;

    // Clear any stale cache for the same log id to keep memory low.
    _cache.removeWhere((k, _) => k.startsWith("${log.id}-"));

    final summaryToUse = summary ?? ShareableRoutineSummary.fromRoutineLog(log);
    final imageBytes =
        await renderer.renderPrimary(context: context, summary: summaryToUse);

    final file = await _persistImage(
      imageBytes: imageBytes,
      completedAt: log.endTime,
    );

    _cache[key] = file;
    return file;
  }

  Future<XFile> _persistImage({
    required Uint8List imageBytes,
    required DateTime completedAt,
  }) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = completedAt.millisecondsSinceEpoch;

    final fileName = 'trackr-summary-$timestamp.png';
    final filePath = p.join(tempDir.path, fileName);
    final file = File(filePath);
    await file.writeAsBytes(imageBytes, flush: true);

    return XFile(
      filePath,
      mimeType: 'image/png',
      name: fileName,
    );
  }
}
