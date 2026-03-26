import 'package:flutter/material.dart';
import 'package:trainware/dtos/coach_dto.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';
import 'package:video_player/video_player.dart';

/// Bottom sheet content: coach profile with Choose Coach CTA.
/// Optional video background (no controls, autoplay, loop). Content overlaid left-aligned.
class CoachProfileBottomSheetContent extends StatefulWidget {
  final CoachDto coach;
  final VoidCallback onChooseCoach;

  const CoachProfileBottomSheetContent({
    super.key,
    required this.coach,
    required this.onChooseCoach,
  });

  @override
  State<CoachProfileBottomSheetContent> createState() =>
      _CoachProfileBottomSheetContentState();
}

class _CoachProfileBottomSheetContentState
    extends State<CoachProfileBottomSheetContent> {
  VideoPlayerController? _videoController;
  bool _videoManuallyPaused = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url = widget.coach.profileVideoUrl?.trim();
    if (url == null || url.isEmpty) return;
    try {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(url));
      _videoController!.setLooping(true);
      // Audible while this sheet is open; [_silenceVideoForDismiss] on close.
      _videoController!.setVolume(1.0);
      await _videoController!.initialize();
      if (!mounted) return;
      if (!_videoManuallyPaused) {
        await _videoController!.play();
      }
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  Future<void> _toggleVideoPlayback() async {
    final url = widget.coach.profileVideoUrl?.trim();
    if (url == null || url.isEmpty) return;

    try {
      final controller = _videoController;
      if (controller == null) {
        _videoManuallyPaused = false;
        await _initVideo();
        return;
      }

      if (!controller.value.isInitialized) {
        _videoManuallyPaused = false;
        await _initVideo();
        return;
      }

      if (controller.value.isPlaying) {
        _videoManuallyPaused = true;
        await controller.pause();
      } else {
        _videoManuallyPaused = false;
        await controller.setVolume(1.0);
        await controller.play();
      }
      if (!mounted) return;
      setState(() {});
    } catch (_) {}
  }

  void _silenceVideoForDismiss() {
    final c = _videoController;
    if (c == null) return;
    try {
      c.setVolume(0.0);
      c.pause();
    } catch (_) {}
  }

  @override
  void deactivate() {
    // Sheet removed: stop playback and mute so audio cannot continue.
    _silenceVideoForDismiss();
    super.deactivate();
  }

  @override
  void dispose() {
    _silenceVideoForDismiss();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasVideo =
        _videoController != null && _videoController!.value.isInitialized;
    final canShowPlayButton =
        (widget.coach.profileVideoUrl?.trim().isNotEmpty ?? false);
    final qualifications = widget.coach.qualifications?.trim();
    final specialties = widget.coach.specialties?.trim();
    final hobbies = widget.coach.interestsHobbies?.trim();
    final combinedPills = <String>[
      ..._splitPills(qualifications),
      ..._splitPills(specialties),
      ..._splitPills(hobbies),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(0),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video background (no controls)
            if (hasVideo)
              Positioned.fill(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _videoController!.value.size.width,
                    height: _videoController!.value.size.height,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              )
            else
              Positioned.fill(
                child: Container(
                  color: theme.colorScheme.surface,
                ),
              ),
            // Dark overlay for legibility
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
            // Profile content overlaid, left-aligned, pushed to bottom
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(26),
                  // Scrollable so additional profile details don't overflow.
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Profile image and name on one horizontal plane
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _buildAvatar(context),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget.coach.name,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  if ((widget.coach.yearsExperience ?? 0) > 0) ...[
                                    const SizedBox(height: 6),
                                    Text(
                                      '${widget.coach.yearsExperience} years experience',
                                      style:
                                          theme.textTheme.bodyMedium?.copyWith(
                                        color: Colors.white
                                            .withValues(alpha: 0.85),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Bio / summary
                        if (widget.coach.description != null &&
                            widget.coach.description!.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            widget.coach.description!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.92),
                            ),
                          ),
                        ],

                        // Extra profile fields
                        if (combinedPills.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          _pillWrapFromList(theme, combinedPills),
                        ],

                        const SizedBox(height: 20),
                        OpacityButtonWidgetTwo(
                          label: 'Choose Coach',
                          buttonColor:
                              theme.extension<TRKRColors>()!.vibrantAccent,
                          onPressed: widget.onChooseCoach,
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (canShowPlayButton)
              Positioned(
                top: 10,
                right: 10,
                child: SafeArea(
                  bottom: false,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.35),
                    shape: const CircleBorder(),
                    child: IconButton(
                      onPressed: _toggleVideoPlayback,
                      icon: Icon(
                        (hasVideo && (_videoController?.value.isPlaying ?? false))
                            ? Icons.pause
                            : Icons.play_arrow,
                        color: Colors.white,
                      ),
                      tooltip: 'Play intro video',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<String> _splitPills(String? pipeSeparated) {
    if (pipeSeparated == null) return const <String>[];
    final trimmed = pipeSeparated.trim();
    if (trimmed.isEmpty) return const <String>[];
    return trimmed
        .split('|')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Widget _pillWrapFromList(ThemeData theme, List<String> items) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.18),
                ),
              ),
              child: Text(
                t,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.coach.profileImageUrl != null &&
        widget.coach.profileImageUrl!.trim().isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          widget.coach.profileImageUrl!,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              _buildPlaceholderAvatar(theme),
        ),
      );
    }
    return _buildPlaceholderAvatar(theme);
  }

  Widget _buildPlaceholderAvatar(ThemeData theme) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color:
            theme.extension<TRKRColors>()?.borderLight ?? Colors.grey.shade300,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        Icons.person,
        size: 36,
        color: Colors.white.withValues(alpha: 0.8),
      ),
    );
  }
}
