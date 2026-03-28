import 'dart:async';
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
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';
import 'package:video_player/video_player.dart';

/// Coach instruction video: coaches add/replace/remove in the **template editor**.
/// During training, playback uses the path from **template_exercises** (linked by
/// [ExerciseLogDto.templateExerciseId]); it is not stored on session rows.
class CoachInstructionVideoSection extends StatefulWidget {
  final ExerciseLogDto exerciseLog;

  /// Non-null when opened from [RoutineTemplateEditorScreen] (workout template id).
  final String? templateId;

  /// Index of this exercise in the template list — used to resolve DB row when
  /// [ExerciseLogDto.templateExerciseId] is stale after a template save.
  final int? templateExerciseOrderIndex;

  /// True only in template editor for coaches — enables upload/remove.
  final bool coachCanEdit;

  const CoachInstructionVideoSection({
    super.key,
    required this.exerciseLog,
    this.templateId,
    this.templateExerciseOrderIndex,
    this.coachCanEdit = false,
  });

  @override
  State<CoachInstructionVideoSection> createState() =>
      _CoachInstructionVideoSectionState();
}

class _CoachInstructionVideoSectionState
    extends State<CoachInstructionVideoSection> {
  VideoPlayerController? _player;
  String? _signedUrl;
  bool _uploading = false;
  bool _loadingSignedUrl = false;
  String? _playbackError;
  int _signedUrlRequestId = 0;
  bool _hasOptimisticOverride = false;
  String? _optimisticStoragePath;

  @override
  void didUpdateWidget(covariant CoachInstructionVideoSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exerciseLog.coachInstructionVideoPath !=
            widget.exerciseLog.coachInstructionVideoPath ||
        oldWidget.exerciseLog.templateExerciseId !=
            widget.exerciseLog.templateExerciseId) {
      _hasOptimisticOverride = false;
      _optimisticStoragePath = null;
      _disposePlayer();
      unawaited(_loadSignedUrl());
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
    _signedUrl = null;
    _playbackError = null;
    _loadingSignedUrl = false;
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  String? get _effectiveStoragePath {
    final raw =
        _hasOptimisticOverride
            ? _optimisticStoragePath
            : widget.exerciseLog.coachInstructionVideoPath;
    final trimmed = raw?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }

  Future<void> _loadSignedUrl() async {
    final path = _effectiveStoragePath;
    _signedUrlRequestId++;
    final reqId = _signedUrlRequestId;
    _player?.dispose();
    _player = null;
    _signedUrl = null;
    _playbackError = null;
    if (path == null || path.isEmpty) {
      if (mounted) {
        setState(() {
          _loadingSignedUrl = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _loadingSignedUrl = true;
      });
    }
    final service = CoachInstructionVideoService();
    final url = await service.createSignedPlaybackUrl(path);
    if (!mounted || reqId != _signedUrlRequestId) return;
    if (url == null || url.isEmpty) {
      setState(() {
        _loadingSignedUrl = false;
        _playbackError = 'Could not open video.';
      });
      return;
    }
    setState(() {
      _signedUrl = url;
      _loadingSignedUrl = false;
    });
    _player = VideoPlayerController.networkUrl(Uri.parse(url));
    _player!
        .initialize()
        .then((_) {
          if (!mounted || reqId != _signedUrlRequestId) return;
          setState(() {});
        })
        .catchError((Object e) {
          if (!mounted || reqId != _signedUrlRequestId) return;
          _player?.dispose();
          _player = null;
          setState(() {
            _playbackError = 'Could not load preview.';
          });
        });
  }

  Future<void> _openFullscreenVideo() async {
    final url = _signedUrl;
    if (url == null || url.isEmpty) return;
    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (_, _, _) => _CoachInstructionFullscreenVideo(url: url),
        transitionDuration: const Duration(milliseconds: 220),
        reverseTransitionDuration: const Duration(milliseconds: 180),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  /// Template editor: coach + client + template id + hint to find `template_exercises` row.
  bool get _canCoachEditTemplate {
    if (!AppConfig.isCoach || !widget.coachCanEdit) return false;
    final access = context.read<ClientOverrideController>();
    if (!access.hasSelectedClient) return false;
    final tid = widget.templateId?.trim();
    if (tid == null || tid.isEmpty) return false;
    final hasId =
        widget.exerciseLog.templateExerciseId?.trim().isNotEmpty ?? false;
    final hasOrder = widget.templateExerciseOrderIndex != null;
    return hasId || hasOrder;
  }

  Future<void> _onPickAndUpload() async {
    if (!_canCoachEditTemplate || _uploading) return;
    final exerciseLogId = widget.exerciseLog.id;
    final templateId = widget.templateId!.trim();
    final exerciseId = widget.exerciseLog.exercise.id;
    final candidateTeId = widget.exerciseLog.templateExerciseId?.trim() ?? '';
    final clientId =
        context.read<ClientOverrideController>().selectedClientId?.trim();
    if (clientId == null || clientId.isEmpty) {
      showErrorBottomSheet(
        context: context,
        message: 'Select a client to add a coaching video.',
      );
      return;
    }

    final routine = context.read<SupabaseExerciseAndRoutineController>();

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
      showErrorBottomSheet(context: context, message: 'Use MP4, MOV, or M4V.');
      return;
    }

    setState(() => _uploading = true);
    final resolvedTeId = await routine.resolveCoachTemplateExerciseRowId(
      templateId: templateId,
      candidateTemplateExerciseId: candidateTeId,
      exerciseId: exerciseId,
      templateExerciseOrderIndex: widget.templateExerciseOrderIndex,
    );
    if (resolvedTeId == null || resolvedTeId.isEmpty) {
      if (!mounted) return;
      setState(() => _uploading = false);
      showErrorBottomSheet(
        context: context,
        message:
            'Save this workout first, then reopen it to attach a coaching video.',
      );
      return;
    }

    final videoSvc = CoachInstructionVideoService();
    final path = await videoSvc.uploadTemplateVideo(
      file: file,
      clientUserId: clientId,
      templateId: templateId,
      templateExerciseId: resolvedTeId,
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

    final ok = await routine.updateCoachTemplateExerciseInstructionVideo(
      templateExerciseId: resolvedTeId,
      newStoragePath: path,
      templateId: templateId,
      exerciseId: exerciseId,
      templateExerciseOrderIndex: widget.templateExerciseOrderIndex,
    );

    if (!mounted) return;
    setState(() => _uploading = false);

    if (!ok) {
      final msg =
          routine.errorMessage.isNotEmpty
              ? routine.errorMessage
              : 'Could not save video link.';
      await videoSvc.deleteVideoAtPath(path);
      if (!mounted) return;
      showErrorBottomSheet(context: context, message: msg);
      routine.clearErrorMessageAfterDisplay();
      return;
    }

    _hasOptimisticOverride = true;
    _optimisticStoragePath = path;
    unawaited(_loadSignedUrl());

    final fresh = routine.templateWhere(id: templateId);
    if (fresh != null) {
      context.read<ExerciseLogController>().loadExerciseLogs(
        exerciseLogs: fresh.exerciseTemplates,
      );
    } else {
      context.read<ExerciseLogController>().applyCoachInstructionVideoPath(
        exerciseLogId: exerciseLogId,
        storagePath: path,
        templateExerciseId: resolvedTeId,
      );
    }
  }

  Future<bool> _confirmRemoveVideo() async {
    var confirmed = false;
    await showAppActionBottomSheet<void>(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Remove coaching video?',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'This removes the video from this exercise in this template. Clients will no longer see it.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OpacityButtonWidgetTwo(
                label: 'Remove video',
                buttonColor: Colors.red,
                onPressed: () {
                  Navigator.of(context).pop();
                  confirmed = true;
                },
              ),
            ),
          ],
        ),
      ),
    );
    return confirmed;
  }

  Future<void> _onRemove() async {
    if (!_canCoachEditTemplate || _uploading) return;
    final confirmed = await _confirmRemoveVideo();
    if (!confirmed || !mounted) return;
    final exerciseLogId = widget.exerciseLog.id;
    final templateId = widget.templateId!.trim();
    final exerciseId = widget.exerciseLog.exercise.id;
    final candidateTeId = widget.exerciseLog.templateExerciseId?.trim() ?? '';
    final prev = widget.exerciseLog.coachInstructionVideoPath?.trim();
    if (prev == null || prev.isEmpty) return;

    final routine = context.read<SupabaseExerciseAndRoutineController>();

    setState(() => _uploading = true);
    final resolvedTeId = await routine.resolveCoachTemplateExerciseRowId(
      templateId: templateId,
      candidateTemplateExerciseId: candidateTeId,
      exerciseId: exerciseId,
      templateExerciseOrderIndex: widget.templateExerciseOrderIndex,
    );
    if (resolvedTeId == null || resolvedTeId.isEmpty) {
      if (!mounted) return;
      setState(() => _uploading = false);
      showErrorBottomSheet(
        context: context,
        message:
            'Save this workout first, then reopen it to change coaching videos.',
      );
      return;
    }

    final ok = await routine.updateCoachTemplateExerciseInstructionVideo(
      templateExerciseId: resolvedTeId,
      newStoragePath: null,
      templateId: templateId,
      exerciseId: exerciseId,
      templateExerciseOrderIndex: widget.templateExerciseOrderIndex,
    );
    if (!mounted) return;
    setState(() => _uploading = false);

    if (!ok) {
      final msg =
          routine.errorMessage.isNotEmpty
              ? routine.errorMessage
              : 'Could not remove video.';
      showErrorBottomSheet(context: context, message: msg);
      routine.clearErrorMessageAfterDisplay();
      return;
    }

    _hasOptimisticOverride = true;
    _optimisticStoragePath = null;
    _disposePlayer();
    setState(() {});

    final fresh = routine.templateWhere(id: templateId);
    if (fresh != null) {
      context.read<ExerciseLogController>().loadExerciseLogs(
        exerciseLogs: fresh.exerciseTemplates,
      );
    } else {
      context.read<ExerciseLogController>().applyCoachInstructionVideoPath(
        exerciseLogId: exerciseLogId,
        storagePath: null,
        templateExerciseId: resolvedTeId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasVideo = _effectiveStoragePath != null;
    final showPreview =
        hasVideo && _signedUrl != null && _signedUrl!.isNotEmpty;

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
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white54),
            ),
          ),
        ],
        if (hasVideo) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: GestureDetector(
              onTap: _openFullscreenVideo,
              child: Container(
                width: 156,
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.black26,
                  border: Border.all(color: Colors.white24),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (showPreview &&
                        _player != null &&
                        _player!.value.isInitialized)
                      SizedBox.expand(
                        child: FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _player!.value.size.width,
                            height: _player!.value.size.height,
                            child: VideoPlayer(_player!),
                          ),
                        ),
                      ),
                    if (_loadingSignedUrl)
                      const CircularProgressIndicator(strokeWidth: 2)
                    else
                      const Icon(
                        Icons.play_circle_fill_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    if (_playbackError != null)
                      Positioned(
                        left: 6,
                        right: 6,
                        bottom: 6,
                        child: Text(
                          _playbackError!,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
        if (_canCoachEditTemplate) ...[
          if (_uploading)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: LinearProgressIndicator(minHeight: 3),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.white54),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _CoachInstructionFullscreenVideo extends StatefulWidget {
  const _CoachInstructionFullscreenVideo({required this.url});

  final String url;

  @override
  State<_CoachInstructionFullscreenVideo> createState() =>
      _CoachInstructionFullscreenVideoState();
}

class _CoachInstructionFullscreenVideoState
    extends State<_CoachInstructionFullscreenVideo> {
  VideoPlayerController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller!
        .initialize()
        .then((_) {
          if (!mounted) return;
          _controller!.play();
          setState(() {
            _loading = false;
          });
        })
        .catchError((Object _) {
          if (!mounted) return;
          setState(() {
            _loading = false;
            _error = 'Could not play video.';
          });
        });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(
            child:
                _loading
                    ? const CircularProgressIndicator(strokeWidth: 2)
                    : (_error != null ||
                        _controller == null ||
                        !_controller!.value.isInitialized)
                    ? Text(
                      _error ?? 'Unable to load video.',
                      style: const TextStyle(color: Colors.white70),
                    )
                    : GestureDetector(
                      onTap: () {
                        setState(() {
                          if (_controller!.value.isPlaying) {
                            _controller!.pause();
                          } else {
                            _controller!.play();
                          }
                        });
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox.expand(
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: _controller!.value.size.width,
                                height: _controller!.value.size.height,
                                child: VideoPlayer(_controller!),
                              ),
                            ),
                          ),
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 150),
                            opacity: _controller!.value.isPlaying ? 0.0 : 1.0,
                            child: const Icon(
                              Icons.play_circle_fill_rounded,
                              color: Colors.white,
                              size: 72,
                            ),
                          ),
                        ],
                      ),
                    ),
          ),
          Positioned(
            top: 12,
            left: 12,
            child: SafeArea(
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const FaIcon(FontAwesomeIcons.solidCircleXmark, size: 22),
                color: Colors.white,
                tooltip: 'Close',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
