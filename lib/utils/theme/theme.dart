import 'package:flutter/material.dart';
import 'package:tracker_app/colors.dart';
import 'package:tracker_app/utils/theme/app_bar_theme.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';
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
      fontFamily: 'Grift',
      scaffoldBackgroundColor: lightBackground,
      primaryColor: freshGreen,
      colorScheme: ColorScheme(
        brightness: Brightness.light,
        primary: freshGreen,
        onPrimary: Colors.white,
        secondary: Colors.grey.shade800,
        onSecondary: Colors.white,
        error: Colors.red.shade600,
        onError: Colors.white,
        surface: lightContainer,
        onSurface: Colors.grey.shade900,
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
      floatingActionButtonTheme: TRKRFloatingActionButtonTheme.lightTheme,
      extensions: const [TRKRColors.light]);

  static ThemeData darkTheme = ThemeData(
      colorScheme: const ColorScheme(
        brightness: Brightness.dark,
        primary: success,
        onPrimary: Colors.white,
        secondary: info,
        onSecondary: Colors.white,
        error: error,
        onError: Colors.white,
        surface: bgSecondary,
        onSurface: textPrimary,
      ),
      useMaterial3: true,
      brightness: Brightness.dark,
      fontFamily: 'Grift',
      scaffoldBackgroundColor: bgPrimary,
      primaryColor: success,
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
      navigationBarTheme: TRKRNavigationBarTheme.darkTheme,
      extensions: const [TRKRColors.dark]);
}
