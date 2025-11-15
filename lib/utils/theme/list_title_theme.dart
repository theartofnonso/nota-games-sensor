import 'package:flutter/material.dart';

class TRKRListTileTheme {
  TRKRListTileTheme._();

  static const ListTileThemeData lightTheme = ListTileThemeData(
      textColor: Color(0xFF212121),
      iconColor: Color(0xFF212121),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12))),
      contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      titleTextStyle: TextStyle(
          fontFamily: 'Grift',
          fontWeight: FontWeight.w600,
          color: Color(0xFF212121),
          fontSize: 15),
      subtitleTextStyle: TextStyle(
          fontFamily: 'Grift',
          fontWeight: FontWeight.w400,
          color: Color(0xFF757575),
          fontSize: 13),
      leadingAndTrailingTextStyle: TextStyle(
          fontFamily: 'Grift',
          fontWeight: FontWeight.w400,
          color: Color(0xFF9E9E9E)));

  static const ListTileThemeData darkTheme = ListTileThemeData(
    textColor: Color(0xFFFFFFFF),
    iconColor: Color(0xFFFFFFFF),
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16))),
    contentPadding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
    titleTextStyle: TextStyle(
        fontFamily: 'Grift',
        fontWeight: FontWeight.w600,
        color: Color(0xFFFFFFFF),
        fontSize: 15),
    subtitleTextStyle: TextStyle(
        fontFamily: 'Grift',
        fontWeight: FontWeight.w400,
        color: Color(0xFFa0a0a0),
        fontSize: 13),
    leadingAndTrailingTextStyle: TextStyle(
        fontFamily: 'Grift',
        fontWeight: FontWeight.w400,
        color: Color(0xFFa0a0a0)),
  );
}
