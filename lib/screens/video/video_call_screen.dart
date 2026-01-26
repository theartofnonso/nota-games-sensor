import 'dart:async';
import 'dart:convert';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/config/video_config.dart';

import '../../utils/agora_chat_utils.dart';
import '../../urls.dart';

class VideoCallScreen extends StatefulWidget {
  final String targetUserId;
  final String? targetName;

  const VideoCallScreen({
    super.key,
    required this.targetUserId,
    this.targetName,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late RtcEngine _engine;
  int? _remoteUid;
  bool _localJoined = false;
  late final String _channelName;

  @override
  void initState() {
    super.initState();
    _channelName = _generateChannelName();
    _initAgora();
  }

  /// Agora channel names must be ≤64 ASCII characters.
  /// UUIDs are 36 chars each, so "call_uuid_uuid" exceeds the limit.
  /// Use a deterministic short form: strip hyphens, sort, take leading chars.
  String _generateChannelName() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final ids = [currentUserId, widget.targetUserId]..sort();
    const maxLen = 64;
    const prefix = 'call_';
    const sep = '_';
    final allowed =
        maxLen - prefix.length - sep.length; // 58 chars for both IDs
    final half = allowed ~/ 2; // 29 chars each
    final a = ids[0].replaceAll('-', '').substring(0, half.clamp(0, 32));
    final b = ids[1].replaceAll('-', '').substring(0, half.clamp(0, 32));
    return '$prefix$a$sep$b';
  }

  Future<void> _initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: VideoConfig.agoraAppId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (_, __) {
          print('onJoinChannelSuccess');
          setState(() => _localJoined = true);
        },
        onUserJoined: (_, uid, __) {
          print('onUserJoined: $uid');
          setState(() => _remoteUid = uid);
        },
        onUserOffline: (_, __, ___) {
          setState(() => _remoteUid = null);
        },
      ),
    );

    await _engine.enableVideo();

    final token = await _resolveVideoToken();

    await _engine.joinChannel(
      token: token!,
      channelId: _channelName,
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  Future<String?> _resolveVideoToken() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final uri = Uri.parse(agoraBaseUrl).resolve(agoraVideoTokenPath);

    final res = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': toAgoraUsername(userId!),
        'channelName': _channelName,
      }),
    );

    return jsonDecode(res.body)['token'];
  }

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  Widget _renderLocalPreview() {
    if (!_localJoined) {
      return const Center(child: CircularProgressIndicator());
    }
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine,
        canvas: const VideoCanvas(
          uid: 0,
          renderMode: RenderModeType.renderModeHidden,
        ),
      ),
    );
  }

  Widget _renderRemoteVideo() {
    if (_remoteUid == null) {
      return const Text(
        'Waiting for remote user…',
        style: TextStyle(color: Colors.white),
      );
    }
    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _engine,
        canvas: VideoCanvas(uid: _remoteUid),
        connection: RtcConnection(channelId: _channelName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Center(child: _renderRemoteVideo()),
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 120,
              height: 160,
              child: _renderLocalPreview(),
            ),
          ),
        ],
      ),
    );
  }
}
