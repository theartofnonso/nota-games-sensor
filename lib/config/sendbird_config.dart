import 'package:flutter/foundation.dart';

/// Configuration for Sendbird Chat SDK
/// Replace with your actual Sendbird App ID from the Sendbird Dashboard
class SendbirdConfig {
  // TODO: Replace with your actual Sendbird App ID
  // You can find this in your Sendbird Dashboard at: https://dashboard.sendbird.com
  static const String appId = kDebugMode
      ? '4E32FD0D-FFE4-4A5E-913C-10BC5962A955' // Development App ID
      : '4E32FD0D-FFE4-4A5E-913C-10BC5962A955'; // Production App ID (can be same or different)

  /// Admin/Coach user ID for one-to-one support chats
  /// This should be a fixed user ID that represents your platform admin/coach
  /// TODO: Replace with your actual admin/coach user ID
  static const String adminUserId = 'f92a43e1-97e4-4048-884c-4c8eb9571546';

  /// Channel name prefix for user support channels
  static const String channelNamePrefix = 'Support Chat';
}
