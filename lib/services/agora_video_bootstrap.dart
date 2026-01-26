import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';

import '../config/video_config.dart';

class AgoraVideoBootstrap {
  static Future<void> _lastRelease = Future<void>.value();

  /// Waits for any previous engine release to complete before creating a new one.
  /// Prevents -7 (ERR_NOT_INITIALIZED) when starting a call shortly after ending one.
  static Future<void> _waitForRelease() async {
    await _lastRelease;
  }

  /// Releases an RTC engine in the correct order: leaveChannel → stopPreview → release.
  /// Call this when ending a video call. Ensures native teardown completes before
  /// createEngine() can run again.
  static Future<void> releaseEngine(RtcEngine? engine) async {
    if (engine == null) return;
    final completer = Completer<void>();
    _lastRelease = completer.future;
    try {
      try {
        await engine.leaveChannel();
      } catch (_) {}
      try {
        await engine.stopPreview();
      } catch (_) {}
      try {
        await engine.release();
      } catch (_) {}
    } finally {
      completer.complete();
    }
  }

  /// Creates and initializes an Agora RTC Engine instance.
  /// Call this when you need to start a video call.
  /// Returns the initialized engine ready to join a channel.
  /// Waits for any previous engine release to finish first.
  static Future<RtcEngine> createEngine() async {
    if (VideoConfig.agoraAppKey.isEmpty) {
      throw Exception('Agora video app key is not configured.');
    }

    await _waitForRelease();

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
