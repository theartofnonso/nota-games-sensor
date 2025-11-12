import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../strings/loading_screen_messages.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

class TRKRLoadingScreen extends StatelessWidget {
  final double opacity;
  final VoidCallback? action;

  const TRKRLoadingScreen({super.key, this.opacity = 0.6, this.action});

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    final children = defaultLoadingMessages
        .map((message) => TypewriterAnimatedText(
              message.toUpperCase(),
              speed: Duration(milliseconds: 90),
              textStyle: Theme.of(context).textTheme.titleMedium,
            ))
        .toList();

    return Scaffold(
      body: Container(
          width: double.infinity,
          height: double.infinity,
          color: isDarkMode ? Theme.of(context).colors.sapphireDark.withValues(alpha:opacity) : Colors.white,
          child: Stack(
            children: [
              if (action != null)
                Positioned.fill(
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: SafeArea(
                      minimum: const EdgeInsets.all(10.0),
                      child: IconButton(
                        icon: const FaIcon(FontAwesomeIcons.squareXmark, size: 28),
                        onPressed: action,
                      ),
                    ),
                  ),
                ),
              Center(
                child: AnimatedTextKit(
                  animatedTexts: children,
                  pause: const Duration(milliseconds: 1000),
                  repeatForever: true,
                  isRepeatingAnimation: true,
                ),
              ),
            ],
          )),
    );
  }
}
