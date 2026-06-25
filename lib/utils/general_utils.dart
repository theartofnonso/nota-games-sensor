import 'package:flutter/material.dart';

import '../colors.dart';

LinearGradient themeGradient({required BuildContext context}) {
  final isDarkMode = Theme.of(context).brightness == Brightness.dark;

  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      isDarkMode ? sapphireDark80 : Colors.white,
      isDarkMode ? sapphireDark : Colors.white12,
    ],
  );
}
