import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:trainware/features/motion_tracking/motion_tracking_controller.dart';
import 'package:trainware/features/motion_tracking/motion_tracking_screen.dart';
import 'package:trainware/utils/theme/system_ui_overlay.dart';
import 'package:trainware/utils/theme/theme.dart';

/// Minimal Trainware shell for NOTA Games motion MVP (no auth / Supabase).
class NotaMotionApp extends StatelessWidget {
  const NotaMotionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MotionTrackingController(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        theme: TRKRTheme.darkTheme,
        darkTheme: TRKRTheme.darkTheme,
        home: const MotionTrackingScreen(),
        builder: (context, child) {
          SystemChrome.setSystemUIOverlayStyle(trkrDarkSystemUiOverlay);
          return child ?? const SizedBox.shrink();
        },
      ),
    );
  }
}
