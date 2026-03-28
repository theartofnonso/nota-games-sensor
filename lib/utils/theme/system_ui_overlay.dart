import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Dark-app status bar + nav bar: light (white) icons on iOS and Android.
///
/// iOS reads [SystemUiOverlayStyle.statusBarBrightness]: [Brightness.dark]
/// means **light-colored** status content. Android uses [statusBarIconBrightness].
const SystemUiOverlayStyle trkrDarkSystemUiOverlay = SystemUiOverlayStyle(
  statusBarColor: Colors.black,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.black,
  systemNavigationBarIconBrightness: Brightness.light,
);
