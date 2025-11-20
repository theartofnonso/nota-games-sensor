import 'package:flutter/material.dart';

class ThemeListTile extends StatelessWidget {
  final Widget child;
  final Color? backgroundColor;

  const ThemeListTile({super.key, required this.child, this.backgroundColor});

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    final color =
        backgroundColor ?? (isDarkMode ? Colors.black12 : Colors.grey.shade100);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: child,
    );
  }
}
