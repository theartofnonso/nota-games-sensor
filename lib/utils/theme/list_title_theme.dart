import 'package:flutter/material.dart';

class TRKRListTileTheme {
  TRKRListTileTheme._();

  static const ListTileThemeData lightTheme = ListTileThemeData(
      textColor: Colors.black,
      iconColor: Colors.black,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(5))),
      contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 20),
      titleTextStyle: TextStyle(
          fontWeight: FontWeight.w600, color: Colors.black, fontSize: 14),
      subtitleTextStyle: TextStyle(
          fontWeight: FontWeight.w400, color: Color(0xFF757575), fontSize: 12),
      leadingAndTrailingTextStyle:
          TextStyle(fontWeight: FontWeight.w400, color: Color(0xFFB3B3B3)));

  static const ListTileThemeData darkTheme = ListTileThemeData(
    textColor: Colors.white,
    iconColor: Colors.white,
    shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(5))),
    contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 20),
    titleTextStyle: TextStyle(
        fontWeight: FontWeight.w600, color: Colors.white, fontSize: 14),
    subtitleTextStyle: TextStyle(
        fontWeight: FontWeight.w400, color: Color(0xFFB3B3B3), fontSize: 12),
    leadingAndTrailingTextStyle:
        TextStyle(fontWeight: FontWeight.w400, color: Color(0xFFB3B3B3)),
  );
}
