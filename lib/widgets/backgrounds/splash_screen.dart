import 'package:flutter/material.dart';

import '../../app_flavor.dart';
import '../../utils/general_utils.dart';

/// Splash screen shown during app startup while blocking activities run.
/// Use for auth restore, subscription check, and other startup tasks.
class SplashScreen extends StatelessWidget {
  /// Optional status message shown below the logo (e.g. "Loading...")
  final String? statusMessage;

  const SplashScreen({super.key, this.statusMessage});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: themeGradient(context: context),
          ),
          child: SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),
                Text(
                  AppConfig.appName,
                  style: const TextStyle(
                  fontFamily: 'GroutpixFlow',
                  color: Colors.white70,
                  fontSize: 24,
                  ),
                ),
              const SizedBox(height: 24),
              if (statusMessage != null && statusMessage!.isNotEmpty) ...[
                Text(
                  statusMessage!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 16),
              ],
              const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
