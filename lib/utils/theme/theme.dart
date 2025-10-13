import 'package:flutter/material.dart';
import 'package:tracker_app/colors.dart';
import 'package:tracker_app/utils/theme/app_bar_theme.dart';
import 'package:tracker_app/utils/theme/floating_action_button_theme.dart';
import 'package:tracker_app/utils/theme/input_textfield_theme.dart';
import 'package:tracker_app/utils/theme/navigation_bar_theme.dart';
import 'package:tracker_app/utils/theme/text_theme.dart';

import 'icon_theme.dart';
import 'list_title_theme.dart';
import 'menu_theme.dart';

class TRKRTheme {
  TRKRTheme._();

  static ThemeData lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      primaryColor: Colors.white,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: Colors.black,
        onPrimary: Colors.white,
        secondary: Colors.black,
        onSecondary: Colors.white,
        error: Colors.black,
        onError: Colors.white,
        surface: Colors.grey.shade200,
        onSurface: Colors.black,
      ),
      textTheme: TRKRTextTheme.lightTheme,
      iconTheme: TRKRIconTheme.lightTheme,
      listTileTheme: TRKRListTileTheme.lightTheme,
      navigationBarTheme: TRKRNavigationBarTheme.lightTheme,
      appBarTheme: TRKRAppBarTheme.lightTheme,
      inputDecorationTheme: TRKRInputTextFieldTheme.lightTheme,
      tabBarTheme: TabBarThemeData(
        indicatorColor: Colors.black,
      ),
      switchTheme: SwitchThemeData(
        thumbColor:
            WidgetStateColor.resolveWith((states) => Colors.grey.shade600),
      ),
      menuBarTheme: TRKRMenuBarTheme.lightTheme,
      textSelectionTheme: TextSelectionThemeData(cursorColor: Colors.white),
      floatingActionButtonTheme: TRKRFloatingActionButtonTheme.lightTheme);

  static ThemeData darkTheme = ThemeData(
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: Colors.white,
        onPrimary: Colors.black,
        secondary: Colors.white,
        onSecondary: Colors.black,
        error: Colors.black,
        onError: Colors.white,
        surface: sapphireDark,
        onSurface: Colors.white,
      ),
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: sapphireDark80,
      primaryColor: Colors.white,
      textTheme: TRKRTextTheme.darkTheme,
      iconTheme: TRKRIconTheme.darkTheme,
      listTileTheme: TRKRListTileTheme.darkTheme,
      floatingActionButtonTheme: TRKRFloatingActionButtonTheme.darkTheme,
      appBarTheme: TRKRAppBarTheme.darkTheme,
      inputDecorationTheme: TRKRInputTextFieldTheme.darkTheme,
      tabBarTheme: TabBarThemeData(
        indicatorColor: Colors.white,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateColor.resolveWith((states) => Colors.white70),
      ),
      menuBarTheme: TRKRMenuBarTheme.darkTheme,
      textSelectionTheme: TextSelectionThemeData(cursorColor: Colors.white),
      navigationBarTheme: TRKRNavigationBarTheme.darkTheme);
}
