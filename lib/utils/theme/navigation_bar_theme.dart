import 'package:flutter/material.dart';
import 'package:tracker_app/colors.dart';

class TRKRNavigationBarTheme {
  TRKRNavigationBarTheme._();

  static NavigationBarThemeData lightTheme = NavigationBarThemeData(
    indicatorColor: Colors.transparent,
    backgroundColor: lightContainer,
    surfaceTintColor: Colors.white,
    overlayColor: WidgetStateColor.resolveWith((states) => Colors.transparent),
    elevation: 0,
  );

  static NavigationBarThemeData darkTheme = NavigationBarThemeData(
    indicatorColor: Colors.transparent,
    backgroundColor: charcoalContainer,
    surfaceTintColor: Colors.black,
    overlayColor: WidgetStateColor.resolveWith((states) => Colors.transparent),
    elevation: 0,
  );
}
