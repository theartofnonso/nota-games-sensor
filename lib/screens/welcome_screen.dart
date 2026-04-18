import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_flavor.dart';
import '../utils/general_utils.dart';
import '../utils/theme/color_extensions.dart';
import '../utils/theme/theme.dart';
import '../widgets/buttons/opacity_button_widget_two.dart';

class WelcomeScreen extends StatefulWidget {
  static const routeName = '/welcome_screen';

  /// Coach app, or legacy single-CTA client path.
  final void Function()? onPressed;

  /// Client: opens coach discovery (pre-auth).
  final void Function()? onDiscoverCoaches;

  /// Client: existing users → sign-in / OTP flow.
  final void Function()? onSignIn;

  const WelcomeScreen({
    super.key,
    this.onPressed,
    this.onDiscoverCoaches,
    this.onSignIn,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
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
          final headingSpans =
              isCoach
                  ? const [
                    TextSpan(
                      text: 'personal training\n',
                      style: TextStyle(color: Colors.white70),
                    ),
                    TextSpan(text: 'that nudges clients\n'),
                    TextSpan(text: 'in the right direction.'),
                  ]
                  : const [
                    TextSpan(text: 'A coach in your\n'),
                    TextSpan(
                      text: 'corner makes all\n',
                      style: TextStyle(color: Colors.white70),
                    ),
                    TextSpan(
                      text: 'the difference',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ];

          return PopScope(
            canPop: false,
            child: AnnotatedRegion<SystemUiOverlayStyle>(
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
                            Text(
                              AppConfig.appName,
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
                            if (isCoach) ...[
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: OpacityButtonWidgetTwo(
                                  label: 'Start Coaching',
                                  onPressed: widget.onPressed,
                                  buttonColor: colors.vibrantAccent,
                                ),
                              ),
                            ] else if (widget.onDiscoverCoaches != null &&
                                widget.onSignIn != null) ...[
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: OpacityButtonWidgetTwo(
                                  label: 'Discover Coaches',
                                  onPressed: widget.onDiscoverCoaches,
                                  buttonColor: colors.vibrantAccent,
                                ),
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: OpacityButtonWidgetTwo(
                                  label: 'Sign In',
                                  onPressed: widget.onSignIn,
                                  buttonColor: colors.vibrantAccent,
                                  solidBackground: true,
                                ),
                              ),
                            ] else if (widget.onSignIn != null) ...[
                              // Unlisted client: no coach discovery; go straight to sign-in.
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: OpacityButtonWidgetTwo(
                                  label: 'Sign In',
                                  onPressed: widget.onSignIn,
                                  buttonColor: colors.vibrantAccent,
                                ),
                              ),
                            ] else ...[
                              SizedBox(
                                width: double.infinity,
                                height: 50,
                                child: OpacityButtonWidgetTwo(
                                  label: 'Start Training',
                                  onPressed: widget.onPressed,
                                  buttonColor: colors.vibrantAccent,
                                ),
                              ),
                            ],
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
