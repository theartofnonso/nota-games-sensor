import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:trainware/dtos/coach_dto.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';
import 'package:trainware/widgets/onboarding/train_with_coach_sheet.dart';
import 'package:trainware/widgets/subscription/paywall_coach_showcase_card.dart';
import 'package:video_player/video_player.dart';

/// Pre-auth coach detail: full-bleed hero + bio + chips; optional intro video via top-right play.
class CoachProfileOnboardingScreen extends StatelessWidget {
  const CoachProfileOnboardingScreen({
    super.key,
    required this.coach,
    this.onSignupSuccess,
    this.onEmailAlreadyExists,
  });

  final CoachDto coach;
  final VoidCallback? onSignupSuccess;
  final VoidCallback? onEmailAlreadyExists;

  /// Opens this screen with a fade (e.g. from coach discovery).
  static Route<void> fadeRoute({
    required CoachDto coach,
    VoidCallback? onSignupSuccess,
    VoidCallback? onEmailAlreadyExists,
  }) {
    return PageRouteBuilder<void>(
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) =>
          CoachProfileOnboardingScreen(
        coach: coach,
        onSignupSuccess: onSignupSuccess,
        onEmailAlreadyExists: onEmailAlreadyExists,
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
            reverseCurve: Curves.easeIn,
          ),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
    );
  }

  void _openTrainSheet(BuildContext context) {
    showTrainWithCoachSheet(
      context: context,
      coach: coach,
      onRequireSignIn: () => onEmailAlreadyExists?.call(),
      onSuccess: () => onSignupSuccess?.call(),
    );
  }

  void _openVideo(BuildContext context) {
    final url = coach.profileVideoUrl?.trim();
    if (url == null || url.isEmpty) return;
    Navigator.of(context).push<void>(
      _CoachIntroVideoPage.fadeRoute(videoUrl: url),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = coach;
    final media = MediaQuery.of(context);
    final h = media.size.height;
    final hasVideo =
        c.profileVideoUrl != null && c.profileVideoUrl!.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          PaywallCoachShowcaseCard(
            coach: c,
            height: h,
            useHero: false,
            bottomAccessory: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OpacityButtonWidgetTwo(
                  label: 'Train with ${c.name}',
                  onPressed: () => _openTrainSheet(context),
                  buttonColor: Theme.of(context).colors.vibrantAccent,
                  outlineColor: Theme.of(context).colors.borderLight,
                  showArrowRight: false,
                ),
                SizedBox(height: media.padding.bottom + 8),
              ],
            ),
          ),
          Positioned(
            top: media.padding.top,
            left: 4,
            child: IconButton(
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
          ),
          if (hasVideo)
            Positioned(
              top: media.padding.top,
              right: 4,
              child: IconButton(
                icon: FaIcon(
                  FontAwesomeIcons.solidCirclePlay,
                  size: 28,
                  color: Colors.white.withValues(alpha: 0.95),
                  shadows: const [
                    Shadow(
                      blurRadius: 12,
                      color: Colors.black54,
                    ),
                  ],
                ),
                onPressed: () => _openVideo(context),
              ),
            ),
        ],
      ),
    );
  }
}

class _CoachIntroVideoPage extends StatefulWidget {
  const _CoachIntroVideoPage({required this.videoUrl});

  final String videoUrl;

  static Route<void> fadeRoute({required String videoUrl}) {
    return PageRouteBuilder<void>(
      opaque: true,
      pageBuilder: (context, animation, secondaryAnimation) =>
          _CoachIntroVideoPage(videoUrl: videoUrl),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
            reverseCurve: Curves.easeIn,
          ),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
    );
  }

  @override
  State<_CoachIntroVideoPage> createState() => _CoachIntroVideoPageState();
}

class _CoachIntroVideoPageState extends State<_CoachIntroVideoPage> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final c = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await c.initialize();
      if (!mounted) {
        await c.dispose();
        return;
      }
      c.setLooping(true);
      await c.play();
      setState(() => _controller = c);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_failed)
            const Center(
              child: Text(
                'Video unavailable',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (_controller != null && _controller!.value.isInitialized)
            Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: VideoPlayer(_controller!),
              ),
            )
          else
            const Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white54,
                ),
              ),
            ),
          Positioned(
            top: media.padding.top,
            left: 4,
            child: IconButton(
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
          ),
        ],
      ),
    );
  }
}
