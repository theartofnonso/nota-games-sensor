import 'package:flutter/material.dart';

class ThemeListTile extends StatelessWidget {
  final Widget child;

  const ThemeListTile({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(5), // Rounded corners
          border: Border.all(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade400,
            width: 1,
          ),
        ),
        child: child);
  }
}
