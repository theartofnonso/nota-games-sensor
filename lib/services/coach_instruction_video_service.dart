import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Upload / delete coach instruction videos (session or template exercise rows).
///
/// **Supabase setup** (manual):
/// 1. Run `20250302120000_session_exercise_coach_video.sql` and
///    `20250302130000_template_exercise_coach_video.sql`
/// 2. Create bucket `coach_instruction_videos` (private).
/// 3. RLS policies: coaches can upload/update/delete objects under paths for
///    their clients; clients can read (signed URLs) for their own sessions.
class CoachInstructionVideoService {
  CoachInstructionVideoService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String bucketName = 'coach_instruction_videos';

  /// Hard cap for MVP (bytes).
  static const int maxFileBytes = 50 * 1024 * 1024;

  static const _uuid = Uuid();

  /// Allowed extensions (lowercase, no dot).
  static bool isAllowedExtension(String filePath) {
    final lower = filePath.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.m4v');
  }

  /// Returns storage path relative to [bucketName], or null on failure.
  Future<String?> uploadVideo({
    required File file,
    required String clientUserId,
    required String sessionId,
    required String sessionExerciseId,
  }) async {
    final len = await file.length();
    if (len > maxFileBytes) {
      debugPrint(
        '[CoachInstructionVideo] File too large: $len > $maxFileBytes',
      );
      return null;
    }
    if (!isAllowedExtension(file.path)) {
      debugPrint('[CoachInstructionVideo] Unsupported format: ${file.path}');
      return null;
    }

    final ext = file.path.toLowerCase().split('.').last;
    final objectPath =
        '$clientUserId/$sessionId/${sessionExerciseId}_${_uuid.v4()}.$ext';

    try {
      await _client.storage.from(bucketName).upload(
            objectPath,
            file,
            fileOptions: const FileOptions(
              upsert: false,
              contentType: 'video/mp4',
            ),
          );
      return objectPath;
    } catch (e, st) {
      debugPrint('[CoachInstructionVideo] Upload failed: $e\n$st');
      return null;
    }
  }

  /// Template editor: path uses `templates/` so it is distinct from session uploads.
  Future<String?> uploadTemplateVideo({
    required File file,
    required String clientUserId,
    required String templateId,
    required String templateExerciseId,
  }) async {
    final len = await file.length();
    if (len > maxFileBytes) {
      debugPrint(
        '[CoachInstructionVideo] File too large: $len > $maxFileBytes',
      );
      return null;
    }
    if (!isAllowedExtension(file.path)) {
      debugPrint('[CoachInstructionVideo] Unsupported format: ${file.path}');
      return null;
    }

    final ext = file.path.toLowerCase().split('.').last;
    final objectPath =
        '$clientUserId/templates/$templateId/${templateExerciseId}_${_uuid.v4()}.$ext';

    try {
      await _client.storage.from(bucketName).upload(
            objectPath,
            file,
            fileOptions: const FileOptions(
              upsert: false,
              contentType: 'video/mp4',
            ),
          );
      return objectPath;
    } catch (e, st) {
      debugPrint('[CoachInstructionVideo] Template upload failed: $e\n$st');
      return null;
    }
  }

  Future<void> deleteVideoAtPath(String? storagePath) async {
    if (storagePath == null || storagePath.trim().isEmpty) return;
    try {
      await _client.storage.from(bucketName).remove([storagePath.trim()]);
    } catch (e) {
      debugPrint('[CoachInstructionVideo] Delete failed (ignored): $e');
    }
  }

  /// Short-lived URL for playback (client or coach preview).
  Future<String?> createSignedPlaybackUrl(
    String storagePath, {
    int expiresInSeconds = 3600,
  }) async {
    if (storagePath.trim().isEmpty) return null;
    try {
      return await _client.storage.from(bucketName).createSignedUrl(
            storagePath.trim(),
            expiresInSeconds,
          );
    } catch (e) {
      debugPrint('[CoachInstructionVideo] Signed URL failed: $e');
      return null;
    }
  }
}
