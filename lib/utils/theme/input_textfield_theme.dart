import 'package:flutter/material.dart';
import 'package:tracker_app/colors.dart';

class TRKRInputTextFieldTheme {
  TRKRInputTextFieldTheme._();

  static InputDecorationTheme lightTheme = InputDecorationTheme(
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: Colors.black.withValues(alpha: 0.1), width: 1)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: freshGreen.withValues(alpha: 0.3), width: 1.5)),
    filled: false,
    hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
  );

  static InputDecorationTheme darkTheme = InputDecorationTheme(
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: borderLight, width: 1)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            BorderSide(color: success.withValues(alpha: 0.5), width: 1.5)),
    filled: false,
    hintStyle:
        TextStyle(color: textPrimary.withValues(alpha: 0.3), fontSize: 14),
  );
}
