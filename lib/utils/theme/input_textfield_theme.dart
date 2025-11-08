import 'package:flutter/material.dart';
import 'package:tracker_app/colors.dart';

class TRKRInputTextFieldTheme {
  TRKRInputTextFieldTheme._();

  static InputDecorationTheme lightTheme = InputDecorationTheme(
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.black.withOpacity(0.1), width: 1)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: freshGreen.withOpacity(0.3), width: 1.5)),
    filled: true,
    fillColor: lightContainer,
    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
  );

  static InputDecorationTheme darkTheme = InputDecorationTheme(
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderLight, width: 1)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: success.withOpacity(0.5), width: 1.5)),
    filled: true,
    fillColor: bgSecondary,
    hintStyle: TextStyle(color: textPrimary.withOpacity(0.3), fontSize: 14),
  );
}
