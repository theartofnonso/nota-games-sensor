import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      themeMode: ThemeMode.system,
      theme: TRKRTheme.lightTheme,
      darkTheme: TRKRTheme.darkTheme,
      home: Builder(
        builder: (context) {
          final colors = Theme.of(context).extension<TRKRColors>()!;

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

                  // ----------------- CONTENT --------------------
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(flex: 2),
                          // Main heading text
                          RichText(
                            textAlign: TextAlign.left,
                            text: const TextSpan(
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                height: 1.2,
                              ),
                              children: [
                                TextSpan(text: 'Where training\n'),
                                TextSpan(
                                  text: 'becomes your\n',
                                  style: TextStyle(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(
                                  text: 'true story.',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 60),
                          // CTA Button
                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: OpacityButtonWidgetTwo(
                              label: "Get Started",
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
