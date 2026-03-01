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
      _videoController!.setVolume(1.0);
      await _videoController!.initialize();
      if (!mounted) return;
      await _videoController!.play();
      if (!mounted) return;
      setState(() {});
    } catch (_) {
      if (mounted) setState(() {});
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasVideo =
        _videoController != null && _videoController!.value.isInitialized;

    return ClipRRect(
      borderRadius: BorderRadius.circular(0),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.6,
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
                            child: Text(
                              widget.coach.name,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      // Description underneath
                      if (widget.coach.description != null &&
                          widget.coach.description!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          widget.coach.description!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 16,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      OpacityButtonWidgetTwo(
                        label: 'Choose Coach',
                        buttonColor:
                            theme.extension<TRKRColors>()!.vibrantAccent,
                        onPressed: widget.onChooseCoach,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
          errorBuilder: (_, __, ___) => _buildPlaceholderAvatar(theme),
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
