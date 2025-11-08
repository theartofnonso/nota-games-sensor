import 'package:flutter/material.dart';
import '../../colors.dart';
import 'icon_theme.dart';

class TRKRAppBarTheme {
  TRKRAppBarTheme._();

  static AppBarTheme lightTheme = AppBarTheme(
      backgroundColor: lightBackground,
      foregroundColor: Colors.grey.shade900,
      actionsIconTheme: TRKRIconTheme.lightTheme,
      titleTextStyle: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey.shade900, fontSize: 16));

  static AppBarTheme darkTheme = AppBarTheme(
      backgroundColor: bgPrimary,
      foregroundColor: textPrimary,
      actionsIconTheme: TRKRIconTheme.darkTheme,
      titleTextStyle: TextStyle(fontWeight: FontWeight.w700, color: textPrimary, fontSize: 16));
}
