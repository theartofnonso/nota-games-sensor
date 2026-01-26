import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_flavor.dart';
import 'utils/general_utils.dart';
import 'utils/theme/color_extensions.dart';
import 'utils/theme/theme.dart';
import 'widgets/buttons/opacity_button_widget_two.dart';

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
      themeMode: ThemeMode.dark,
      theme: TRKRTheme.darkTheme,
      darkTheme: TRKRTheme.darkTheme,
      home: Builder(
        builder: (context) {
          final colors = Theme.of(context).extension<TRKRColors>()!;
          final isCoach = AppConfig.isCoach;
          final headingSpans = isCoach
              ? const [
                  TextSpan(text: 'personal training\n'),
                  TextSpan(
                    text: 'that nudges clients\n',
                  ),
                  TextSpan(
                    text: 'in the right direction.',
                  ),
                ]
              : const [
                  TextSpan(text: 'adaptive training\n'),
                  TextSpan(
                    text: 'that nudges you\n',
                  ),
                  TextSpan(
                    text: 'in the right direction.',
                  ),
                ];

          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            ),
            child: Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                children: [
                  // ----------------- GRADIENT BACKGROUND -----------------
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: themeGradient(context: context),
                      ),
                    ),
                  ),
                  // Gradient overlay for readability
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.55),
                            Colors.black.withValues(alpha: 0.75),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ----------------- CONTENT --------------------
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(flex: 2),
                          Text(
                            isCoach ? 'Not Athletes Coach' : 'Not Athletes',
                            style: const TextStyle(
                              fontFamily: 'GroutpixFlow',
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 28),
                          // Main heading text
                          RichText(
                            textAlign: TextAlign.left,
                            text: TextSpan(
                              style: TextStyle(
                                fontFamily: 'Grift',
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                              children: headingSpans,
                            ),
                          ),
                          const SizedBox(height: 60),
                          // CTA Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OpacityButtonWidgetTwo(
                              label:
                                  isCoach ? "Start Coaching" : "Start Training",
                              onPressed: widget.onPressed,
                              buttonColor: colors.vibrantAccent,
                            ),
                          ),
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
