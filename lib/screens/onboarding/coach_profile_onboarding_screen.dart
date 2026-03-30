import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:trainware/dtos/coach_dto.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';
import 'package:trainware/widgets/onboarding/train_with_coach_sheet.dart';
import 'package:trainware/widgets/subscription/paywall_coach_showcase_card.dart';
import 'package:video_player/video_player.dart';

/// Pre-auth coach detail: same hero + bio + chips as the paywall; video + CTA below.
class CoachProfileOnboardingScreen extends StatefulWidget {
  const CoachProfileOnboardingScreen({
    super.key,
    required this.coach,
    this.onSignupSuccess,
    this.onEmailAlreadyExists,
  });

  final CoachDto coach;
  final VoidCallback? onSignupSuccess;
  final VoidCallback? onEmailAlreadyExists;

  @override
  State<CoachProfileOnboardingScreen> createState() =>
      _CoachProfileOnboardingScreenState();
}

class _CoachProfileOnboardingScreenState
    extends State<CoachProfileOnboardingScreen> {
  VideoPlayerController? _videoController;
  bool _videoInitFailed = false;
  bool _videoReady = false;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _ensureVideoStarted() async {
    final url = widget.coach.profileVideoUrl?.trim();
    if (url == null || url.isEmpty) return;

    if (_videoController != null) {
      if (_videoController!.value.isPlaying) {
        await _videoController!.pause();
      } else {
        await _videoController!.play();
      }
      setState(() {});
      return;
    }

    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(url));
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      _videoController = c;
      c.setLooping(true);
      await c.play();
      setState(() => _videoReady = true);
    } catch (_) {
      if (mounted) setState(() => _videoInitFailed = true);
    }
  }

  void _openTrainSheet() {
    showTrainWithCoachSheet(
      context: context,
      coach: widget.coach,
      onRequireSignIn: () => widget.onEmailAlreadyExists?.call(),
      onSuccess: () => widget.onSignupSuccess?.call(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.coach;
    final media = MediaQuery.of(context);
    final heroH = (media.size.height * 0.52).clamp(360.0, 580.0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: themeGradient(context: context),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: heroH,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PaywallCoachShowcaseCard(
                    coach: c,
                    height: heroH,
                    useHero: false,
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: media.padding.top,
                        left: 4,
                      ),
                      child: Row(
                        children: [
                          IconButton(
                            icon: FaIcon(
                              FontAwesomeIcons.solidCircleXmark,
                              size: 28,
                              color: Colors.white.withValues(alpha: 0.95),
                              shadows: const [
                                Shadow(
                                  blurRadius: 12,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const Spacer(),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  20,
                  24,
                  20,
                  32 + media.padding.bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (c.profileVideoUrl != null &&
                        c.profileVideoUrl!.trim().isNotEmpty) ...[
                      _IntroVideoCard(
                        videoReady: _videoReady,
                        initFailed: _videoInitFailed,
                        controller: _videoController,
                        onTapPlay: _ensureVideoStarted,
                      ),
                      const SizedBox(height: 24),
                    ],
                    OpacityButtonWidgetTwo(
                      label: 'Train with ${c.name}',
                      onPressed: _openTrainSheet,
                      buttonColor: Theme.of(context).colors.vibrantAccent,
                      showArrowRight: false,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntroVideoCard extends StatelessWidget {
  const _IntroVideoCard({
    required this.videoReady,
    required this.initFailed,
    required this.controller,
    required this.onTapPlay,
  });

  final bool videoReady;
  final bool initFailed;
  final VideoPlayerController? controller;
  final VoidCallback onTapPlay;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: initFailed ? null : onTapPlay,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color:
                (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (videoReady && controller != null)
                  FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: controller!.value.size.width,
                      height: controller!.value.size.height,
                      child: VideoPlayer(controller!),
                    ),
                  )
                else
                  ColoredBox(
                    color: Colors.black.withValues(alpha: 0.35),
                    child: Center(
                      child: initFailed
                          ? Text(
                              'Video unavailable',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.white.withValues(
                                      alpha: 0.95,
                                    ),
                                    fontWeight: FontWeight.w600,
                                  ),
                            )
                          : Icon(
                              Icons.play_circle_fill_rounded,
                              size: 56,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                    ),
                  ),
                if (videoReady &&
                    controller != null &&
                    !controller!.value.isPlaying)
                  Center(
                    child: Icon(
                      Icons.play_circle_fill_rounded,
                      size: 56,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
