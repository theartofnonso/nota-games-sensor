import 'package:flutter/material.dart';
import 'package:tracker_app/colors.dart';

class TRKRFloatingActionButtonTheme {
  TRKRFloatingActionButtonTheme._();

  static FloatingActionButtonThemeData lightTheme = FloatingActionButtonThemeData(
      backgroundColor: freshGreen,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      foregroundColor: Colors.white,
      elevation: 2,
      );

  static FloatingActionButtonThemeData darkTheme = FloatingActionButtonThemeData(
    backgroundColor: success,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    foregroundColor: Colors.white,
    elevation: 8,
  );
}
