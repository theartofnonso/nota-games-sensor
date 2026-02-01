import 'package:flutter/foundation.dart';

import 'package:trainware/app_flavor.dart';

/// Configuration for chat service
/// Simple config for coach/admin user ID
class ChatConfig {
  ChatConfig._();

  /// Agora Chat app key from Agora Console
  static const String agoraAppKey = '4110016020#1651775';

  /// APNs certificate name from Agora Console. Chosen by flavor (coach/client)
  /// and build: release → Production cert, debug/profile → Sandbox cert.
  /// Must match exactly the "Certificate Name" in: Agora Console → Project →
  /// Config → Chat → Features → Push Certificate (Apple tab). Used only on iOS.
  static String get apnsCertName {
    final part = AppConfig.isCoach ? 'Coach' : 'Client';
    final env = kReleaseMode ? 'Production' : 'Sandbox';
    return '$part App $env APNs Certificate';
  }
}
