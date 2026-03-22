import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/controllers/access_controller.dart';
import 'package:trainware/controllers/exercise_log_controller.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';
import 'package:trainware/services/coach_instruction_video_service.dart';
import 'package:trainware/utils/dialog_utils.dart';
import 'package:video_player/video_player.dart';

/// Coach instruction video: coaches add/replace/remove in the **template editor**.
/// During training, playback uses the path from **template_exercises** (linked by
/// [ExerciseLogDto.templateExerciseId]); it is not stored on session rows.
class CoachInstructionVideoSection extends StatefulWidget {
  final ExerciseLogDto exerciseLog;

  /// Non-null when opened from [RoutineTemplateEditorScreen] (workout template id).
  final String? templateId;

  /// True only in template editor for coaches — enables upload/remove.
  final bool coachCanEdit;

  const CoachInstructionVideoSection({
    super.key,
    required this.exerciseLog,
    this.templateId,
    this.coachCanEdit = false,
  });

  @override
  State<CoachInstructionVideoSection> createState() =>
      _CoachInstructionVideoSectionState();
}

class _CoachInstructionVideoSectionState
    extends State<CoachInstructionVideoSection> {
  VideoPlayerController? _player;
  Future<void>? _init;
  String? _signedUrl;
  bool _uploading = false;

  @override
  void didUpdateWidget(covariant CoachInstructionVideoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exerciseLog.coachInstructionVideoPath !=
            widget.exerciseLog.coachInstructionVideoPath ||
        oldWidget.exerciseLog.templateExerciseId !=
            widget.exerciseLog.templateExerciseId) {
      _disposePlayer();
      _loadSignedUrl();
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSignedUrl();
  }

  void _disposePlayer() {
    _player?.dispose();
    _player = null;
    _init = null;
    _signedUrl = null;
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  Future<void> _loadSignedUrl() async {
    final path = widget.exerciseLog.coachInstructionVideoPath?.trim();
    if (path == null || path.isEmpty) {
      if (mounted) setState(() {});
      return;
    }
    final service = CoachInstructionVideoService();
    final url = await service.createSignedPlaybackUrl(path);
    if (!mounted) return;
    setState(() => _signedUrl = url);
    if (url == null || url.isEmpty) return;
    _player = VideoPlayerController.networkUrl(Uri.parse(url));
    _init = _player!.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  /// Template editor: coach + client + saved template row ids.
  bool get _canCoachEditTemplate {
    if (!AppConfig.isCoach || !widget.coachCanEdit) return false;
    final access = context.read<ClientOverrideController>();
    if (!access.hasSelectedClient) return false;
    final te = widget.exerciseLog.templateExerciseId?.trim();
    if (te == null || te.isEmpty) return false;
    final tid = widget.templateId?.trim();
    return tid != null && tid.isNotEmpty;
  }

  Future<void> _onPickAndUpload() async {
    if (!_canCoachEditTemplate || _uploading) return;
    final templateExerciseId = widget.exerciseLog.templateExerciseId!;
    final exerciseLogId = widget.exerciseLog.id;
    final templateId = widget.templateId!.trim();
    final clientId =
        context.read<ClientOverrideController>().selectedClientId?.trim();
    if (clientId == null || clientId.isEmpty) {
      showErrorBottomSheet(
        context: context,
        message: 'Select a client to add a coaching video.',
      );
      return;
    }

    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null || !mounted) return;

    final file = File(picked.path);
    final len = await file.length();
    if (len > CoachInstructionVideoService.maxFileBytes) {
      if (!mounted) return;
      showErrorBottomSheet(
        context: context,
        message:
            'Video is too large (max ${CoachInstructionVideoService.maxFileBytes ~/ (1024 * 1024)} MB).',
      );
      return;
    }
    if (!CoachInstructionVideoService.isAllowedExtension(picked.path)) {
      if (!mounted) return;
      showErrorBottomSheet(
        context: context,
        message: 'Use MP4, MOV, or M4V.',
      );
      return;
    }

    setState(() => _uploading = true);
    final videoSvc = CoachInstructionVideoService();
    final path = await videoSvc.uploadTemplateVideo(
      file: file,
      clientUserId: clientId,
      templateId: templateId,
      templateExerciseId: templateExerciseId,
    );

    if (!mounted) return;

    if (path == null || path.isEmpty) {
      setState(() => _uploading = false);
      showErrorBottomSheet(
        context: context,
        message: 'Upload failed. Check your connection and try again.',
      );
      return;
    }

    final routine = context.read<SupabaseExerciseAndRoutineController>();
    final prev = widget.exerciseLog.coachInstructionVideoPath?.trim();
    final ok = await routine.updateCoachTemplateExerciseInstructionVideo(
      templateExerciseId: templateExerciseId,
      newStoragePath: path,
      previousStoragePath: prev,
    );

    if (!mounted) return;
    setState(() => _uploading = false);

    if (!ok) {
      final msg = routine.errorMessage.isNotEmpty
          ? routine.errorMessage
          : 'Could not save video link.';
      await videoSvc.deleteVideoAtPath(path);
      if (!mounted) return;
      showErrorBottomSheet(context: context, message: msg);
      return;
    }

    final fresh = routine.templateWhere(id: templateId);
    if (fresh != null) {
      context.read<ExerciseLogController>().loadExerciseLogs(
            exerciseLogs: fresh.exerciseTemplates,
          );
    } else {
      context.read<ExerciseLogController>().applyCoachInstructionVideoPath(
            exerciseLogId: exerciseLogId,
            storagePath: path,
            templateExerciseId: templateExerciseId,
          );
    }
  }

  Future<void> _onRemove() async {
    if (!_canCoachEditTemplate || _uploading) return;
    final templateExerciseId = widget.exerciseLog.templateExerciseId!;
    final exerciseLogId = widget.exerciseLog.id;
    final templateId = widget.templateId!.trim();
    final prev = widget.exerciseLog.coachInstructionVideoPath?.trim();
    if (prev == null || prev.isEmpty) return;

    setState(() => _uploading = true);
    final routine = context.read<SupabaseExerciseAndRoutineController>();
    final ok = await routine.updateCoachTemplateExerciseInstructionVideo(
      templateExerciseId: templateExerciseId,
      newStoragePath: null,
      previousStoragePath: prev,
    );
    if (!mounted) return;
    setState(() => _uploading = false);

    if (!ok) {
      showErrorBottomSheet(
        context: context,
        message: routine.errorMessage.isNotEmpty
            ? routine.errorMessage
            : 'Could not remove video.',
      );
      return;
    }

    final fresh = routine.templateWhere(id: templateId);
    if (fresh != null) {
      context.read<ExerciseLogController>().loadExerciseLogs(
            exerciseLogs: fresh.exerciseTemplates,
          );
    } else {
      context.read<ExerciseLogController>().applyCoachInstructionVideoPath(
            exerciseLogId: exerciseLogId,
            storagePath: null,
            templateExerciseId: templateExerciseId,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.exerciseLog.coachInstructionVideoPath?.trim();
    final hasVideo = path != null && path.isNotEmpty;
    final showPlayer = hasVideo && (_signedUrl != null && _signedUrl!.isNotEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.coachCanEdit &&
            !_canCoachEditTemplate &&
            AppConfig.isCoach) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              !context.read<ClientOverrideController>().hasSelectedClient
                  ? 'Select a client to add coaching videos to their workout templates.'
                  : 'Save this workout first, then reopen it to attach a coaching video.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.white54),
            ),
          ),
        ],
        if (showPlayer) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: FutureBuilder<void>(
              future: _init,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done ||
                    _player == null ||
                    !_player!.value.isInitialized) {
                  return const AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return AspectRatio(
                  aspectRatio: _player!.value.aspectRatio == 0
                      ? 16 / 9
                      : _player!.value.aspectRatio,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(_player!),
                      Material(
                        color: Colors.black45,
                        shape: const CircleBorder(),
                        child: IconButton(
                          iconSize: 40,
                          color: Colors.white,
                          icon: Icon(
                            _player!.value.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                          ),
                          onPressed: () {
                            setState(() {
                              if (_player!.value.isPlaying) {
                                _player!.pause();
                              } else {
                                _player!.play();
                              }
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
        if (_canCoachEditTemplate) ...[
          if (_uploading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(minHeight: 3),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    onTap: _onPickAndUpload,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: FaIcon(
                          hasVideo
                              ? FontAwesomeIcons.arrowsRotate
                              : FontAwesomeIcons.video,
                          size: 24,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  ),
                  if (hasVideo) ...[
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: _onRemove,
                      icon: const FaIcon(
                        FontAwesomeIcons.trash,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      tooltip: 'Remove video',
                    ),
                  ],
                  if (!hasVideo) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        'Tap to add a coaching video',
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: Colors.white54),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'MP4/MOV/M4V · max ${CoachInstructionVideoService.maxFileBytes ~/ (1024 * 1024)} MB',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: Colors.white38),
              ),
            ),
          ],
        ],
      ],
    );
  }
}
