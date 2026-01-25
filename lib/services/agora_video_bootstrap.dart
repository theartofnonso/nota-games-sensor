import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../config/video_config.dart';

class AgoraVideoBootstrap {
  /// Creates and initializes an Agora RTC Engine instance.
  /// Call this when you need to start a video call.
  /// Returns the initialized engine ready to join a channel.
  static Future<RtcEngine> createEngine() async {
    if (VideoConfig.agoraAppKey.isEmpty) {
      throw Exception('Agora video app key is not configured.');
    }

    // Extract app ID (part before #) if format is "appId#region"
    final appId = VideoConfig.agoraAppKey.split('#').first;

    final engine = createAgoraRtcEngine();

    try {
      await engine.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
    } catch (e) {
      await engine.release();
      rethrow;
    }

    return engine;
  }

  /// Gets the app ID for video calls (extracted from app key)
  static String get appId {
    return VideoConfig.agoraAppKey.split('#').first;
  }
}
