import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:tracker_app/colors.dart';
import 'package:video_player/video_player.dart';

import 'utils/theme/theme.dart';
import 'widgets/buttons/opacity_button_widget_two.dart';

// ---------------------------------------------------------------------------
//  FULL‑SCREEN VIDEO + SOFT BLUR + OVERLAYED TEXT & CTA BUTTON
// ---------------------------------------------------------------------------
//  * Plays an asset‑based video that fills the screen (autoplay + loop).
//  * Applies a configurable gaussian blur (`blurSigma`) over the video.
//  * Adds a fade gradient for readability plus headline & button at bottom.
// ---------------------------------------------------------------------------

class OnboardingFlowScreen extends StatefulWidget {
  static const routeName = '/onboarding_flow_screen';

  final void Function()? onPressed;

  const OnboardingFlowScreen({super.key, this.onPressed});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset("images/video.MOV")
      ..setLooping(true)
      ..setVolume(0)
      ..setLooping(true)
      ..initialize().then((_) {
        setState(() {});
        _controller.play();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      themeMode: ThemeMode.system,
      theme: TRKRTheme.lightTheme,
      darkTheme: TRKRTheme.darkTheme,
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // ----------------- FULL‑SCREEN VIDEO -----------------
            Positioned.fill(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),

            // ----------------- BLUR LAYER ------------------------
            // Uses BackdropFilter to blur everything beneath it.
            Positioned.fill(
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: 5.0,
                    sigmaY: 5.0,
                  ),
                  child: Container(
                    // transparent container is required
                    color: Colors.transparent,
                  ),
                ),
              ),
            ),

            // ----------------- TOP→BOTTOM FADE ------------------
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
              ),
            ),
            // ----------------- BOTTOM OVERLAY --------------------
            Align(
              alignment: Alignment.bottomCenter,
              child: SafeArea(
                minimum: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Image.asset(
                      'images/framer_logo.png',
                      fit: BoxFit.contain,
                      color: Colors.white,
                      height: 60, // Adjust the height as needed
                    ),
                    Text(
                      "Training is tough. Let's tell you what to do instead.",
                      textAlign: TextAlign.start,
                      style: TextStyle(
                            color: Colors.white70,
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OpacityButtonWidgetTwo(
                          label: "Start training better", onPressed: widget.onPressed, buttonColor: vibrantGreen),
                    )
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
