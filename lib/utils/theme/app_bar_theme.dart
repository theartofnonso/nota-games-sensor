import 'package:flutter/material.dart';
import '../../colors.dart';
import 'icon_theme.dart';

class TRKRAppBarTheme {
  TRKRAppBarTheme._();

  static AppBarTheme lightTheme = AppBarTheme(
      backgroundColor: lightBackground,
      foregroundColor: Colors.grey.shade900,
      actionsIconTheme: TRKRIconTheme.lightTheme,
      titleTextStyle: const TextStyle(
          fontFamily: 'Grift',
          fontWeight: FontWeight.w700,
          color: Colors.black,
          fontSize: 16));

  static AppBarTheme darkTheme = AppBarTheme(
      backgroundColor: bgPrimary,
      foregroundColor: textPrimary,
      actionsIconTheme: TRKRIconTheme.darkTheme,
      titleTextStyle: const TextStyle(
          fontFamily: 'Grift',
          fontWeight: FontWeight.w700,
          color: textPrimary,
          fontSize: 16));
}
