import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TRKRTextTheme {
  TRKRTextTheme._();

  static TextTheme get lightTheme => GoogleFonts.spaceMonoTextTheme(
        const TextTheme(
          displaySmall: TextStyle(
              fontWeight: FontWeight.w400, color: Colors.black, fontSize: 36),
          displayMedium: TextStyle(
              fontWeight: FontWeight.w600, color: Colors.black, fontSize: 45),
          displayLarge: TextStyle(
              fontWeight: FontWeight.w900, color: Colors.black, fontSize: 57),
          headlineSmall: TextStyle(
              fontWeight: FontWeight.w700, color: Colors.black, fontSize: 24),
          headlineMedium: TextStyle(
              fontWeight: FontWeight.w700, color: Colors.black, fontSize: 28),
          headlineLarge: TextStyle(
              fontWeight: FontWeight.w700, color: Colors.black, fontSize: 32),
          titleSmall: TextStyle(
              fontWeight: FontWeight.w500, color: Colors.black, fontSize: 14),
          titleMedium: TextStyle(
              fontWeight: FontWeight.w600, color: Colors.black, fontSize: 16),
          titleLarge: TextStyle(
              fontWeight: FontWeight.w600, color: Colors.black, fontSize: 22),
          labelSmall: TextStyle(
              fontWeight: FontWeight.w500, color: Colors.black, fontSize: 11),
          labelMedium: TextStyle(
              fontWeight: FontWeight.w600, color: Colors.black, fontSize: 12),
          labelLarge: TextStyle(
              fontWeight: FontWeight.w600, color: Colors.black, fontSize: 14),
          bodySmall: TextStyle(
              fontWeight: FontWeight.w400, color: Colors.black, fontSize: 12),
          bodyMedium: TextStyle(
              fontWeight: FontWeight.w400, color: Colors.black, fontSize: 14),
          bodyLarge: TextStyle(
              fontWeight: FontWeight.w400, color: Colors.black, fontSize: 16),
        ),
      );

  static TextTheme get darkTheme => GoogleFonts.spaceMonoTextTheme(
        const TextTheme(
          displaySmall: TextStyle(
              fontWeight: FontWeight.w400, color: Colors.white, fontSize: 36),
          displayMedium: TextStyle(
              fontWeight: FontWeight.w600, color: Colors.white, fontSize: 45),
          displayLarge: TextStyle(
              fontWeight: FontWeight.w900, color: Colors.white, fontSize: 57),
          headlineSmall: TextStyle(
              fontWeight: FontWeight.w700, color: Colors.white, fontSize: 24),
          headlineMedium: TextStyle(
              fontWeight: FontWeight.w700, color: Colors.white, fontSize: 28),
          headlineLarge: TextStyle(
              fontWeight: FontWeight.w700, color: Colors.white, fontSize: 32),
          titleSmall: TextStyle(
              fontWeight: FontWeight.w500, color: Colors.white, fontSize: 14),
          titleMedium: TextStyle(
              fontWeight: FontWeight.w600, color: Colors.white, fontSize: 16),
          titleLarge: TextStyle(
              fontWeight: FontWeight.w600, color: Colors.white, fontSize: 22),
          labelSmall: TextStyle(
              fontWeight: FontWeight.w500, color: Colors.white, fontSize: 11),
          labelMedium: TextStyle(
              fontWeight: FontWeight.w600, color: Colors.white, fontSize: 12),
          labelLarge: TextStyle(
              fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14),
          bodySmall: TextStyle(
              fontWeight: FontWeight.w400, color: Colors.white, fontSize: 12),
          bodyMedium: TextStyle(
              fontWeight: FontWeight.w400, color: Colors.white, fontSize: 14),
          bodyLarge: TextStyle(
              fontWeight: FontWeight.w400, color: Colors.white, fontSize: 16),
        ),
      );
}
