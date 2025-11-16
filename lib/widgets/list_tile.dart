import 'package:flutter/material.dart';

class ThemeListTile extends StatelessWidget {
  final Widget child;

  const ThemeListTile({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.black12 : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: child);
  }
}
