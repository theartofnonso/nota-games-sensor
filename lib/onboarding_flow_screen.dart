import 'package:flutter/material.dart';

import 'package:tracker_app/colors.dart';

import 'utils/theme/theme.dart';
import 'widgets/buttons/opacity_button_widget_two.dart';
import 'widgets/custom_logo.dart';

class OnboardingFlowScreen extends StatefulWidget {
  static const routeName = '/onboarding_flow_screen';

  final void Function()? onPressed;

  const OnboardingFlowScreen({super.key, this.onPressed});

  @override
  State<OnboardingFlowScreen> createState() => _OnboardingFlowScreenState();
}

class _OnboardingFlowScreenState extends State<OnboardingFlowScreen> {
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
            // ----------------- GRADIENT BACKGROUND -----------------
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [vibrantBlue, vibrantGreen],
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
                    const CustomLogo(
                      size: 60,
                      innerColor: Colors.white,
                      middleColor: Colors.grey,
                      outerColor: Colors.white54,
                    ),
                    const SizedBox(height: 12),
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
                          label: "Start training better",
                          onPressed: widget.onPressed,
                          buttonColor: Colors.white),
                    ),
                    const SizedBox(height: 40),
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
