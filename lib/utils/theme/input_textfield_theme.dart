import 'package:flutter/material.dart';


class TRKRInputTextFieldTheme {
  TRKRInputTextFieldTheme._();

  static InputDecorationTheme lightTheme = InputDecorationTheme(
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5), borderSide: const BorderSide(color: Colors.black38)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5), borderSide: const BorderSide(color: Colors.black38)),
    filled: true,
    fillColor: Colors.grey.shade200,
    hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
  );

  static InputDecorationTheme darkTheme = InputDecorationTheme(
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5), borderSide: const BorderSide(color: Colors.white10)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(5), borderSide: const BorderSide(color: Colors.white10)),
    filled: true,
    fillColor: Colors.transparent,
    hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
  );
}
