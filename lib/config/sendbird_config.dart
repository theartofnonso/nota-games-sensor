import 'package:flutter/foundation.dart';

/// Configuration for Sendbird Chat SDK
/// Replace with your actual Sendbird App ID from the Sendbird Dashboard
class SendbirdConfig {
  // TODO: Replace with your actual Sendbird App ID
  // You can find this in your Sendbird Dashboard at: https://dashboard.sendbird.com
  static const String appId = kDebugMode
      ? 'YOUR_SENDBIRD_APP_ID' // Development App ID
      : 'YOUR_SENDBIRD_APP_ID'; // Production App ID (can be same or different)

  /// Admin/Coach user ID for one-to-one support chats
  /// This should be a fixed user ID that represents your platform admin/coach
  /// TODO: Replace with your actual admin/coach user ID
  static const String adminUserId = 'admin_user_id';

  /// Channel name prefix for user support channels
  static const String channelNamePrefix = 'Support Chat';
}
