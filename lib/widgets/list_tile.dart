import 'package:flutter/material.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

class ThemeListTile extends StatelessWidget {
  final Widget child;

  const ThemeListTile({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return Container(
        decoration: BoxDecoration(
          color: isDarkMode ? Theme.of(context).colors.sapphireDark80 : Colors.grey.shade200, // Background color
          borderRadius: BorderRadius.circular(5), // Rounded corners
        ),
        child: child);
  }
}
