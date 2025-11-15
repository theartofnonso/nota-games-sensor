
import 'package:flutter/material.dart';

class GoogleHealthIcon extends StatelessWidget {
  const GoogleHealthIcon({
    super.key,
    required this.isDarkMode,
    required this.height,
    this.elevation = true
  });

  final bool isDarkMode;
  final double height;
  final bool elevation;

  @override
  Widget build(BuildContext context) {

    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return Container(
        decoration: elevation ? BoxDecoration(
          boxShadow: isDarkMode
              ? null
              : [
            BoxShadow(
              color: Colors.grey.shade300,
              spreadRadius: 3,
              blurRadius: 10,
              offset: const Offset(0, 3), // changes position of shadow
            ),
          ],
        ) : null,
        child: Image.asset(
          'images/google_health.png',
          fit: BoxFit.contain,
          height: height, // Adjust the height as needed
        ));
  }
}