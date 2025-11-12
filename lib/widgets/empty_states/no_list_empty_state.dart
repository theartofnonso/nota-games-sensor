import 'package:flutter/material.dart';

class NoListEmptyState extends StatelessWidget {
  final String message;

  const NoListEmptyState({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: Text(message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: isDarkMode ? Colors.white70 : Colors.grey.shade400)),
      ),
    );
  }
}
