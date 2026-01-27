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
  int? _remoteUid; // Stores remote user ID
  bool _localUserJoined =
      false; // Indicates if local user has joined the channel
  late RtcEngine _engine; // Stores Agora RTC Engine instance
  @override
  void initState() {
    super.initState();
    _startVideoCalling();
  }

  // Initializes Agora SDK
  Future<void> _startVideoCalling() async {
    await _requestPermissions();
    await _initializeAgoraVideoSDK();
    await _setupLocalVideo();
    _setupEventHandlers();
    await _joinChannel();
  }

  // Requests microphone and camera permissions
  Future<void> _requestPermissions() async {
    await [Permission.microphone, Permission.camera].request();
  }

  // Set up the Agora RTC engine instance
  Future<void> _initializeAgoraVideoSDK() async {
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: VideoConfig.agoraAppId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));
  }

  // Enables and starts local video preview
  Future<void> _setupLocalVideo() async {
    await _engine.enableVideo();
    await _engine.startPreview();
  }

  // Register an event handler for Agora RTC
  void _setupEventHandlers() {
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("Local user ${connection.localUid} joined");
          setState(() => _localUserJoined = true);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("Remote user $remoteUid joined");
          setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          debugPrint("Remote user $remoteUid left");
          setState(() => _remoteUid = null);
        },
      ),
    );
  }

  // Join a channel
  Future<void> _joinChannel() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw StateError('No user ID');

    final agoraUsername = toAgoraUsername(userId);
    final token = await _resolveVideoToken();
    if (token == null || token.isEmpty) throw StateError('No token');

    await _engine.joinChannelWithUserAccount(
      token: token,
      channelId: _generateChannelName(),
      userAccount: agoraUsername,
      options: const ChannelMediaOptions(
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

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

  Future<String?> _resolveVideoToken() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    final uri = Uri.parse(agoraBaseUrl).resolve(agoraVideoTokenPath);

    final res = await http.post(
      uri,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'userId': toAgoraUsername(userId!),
        'channelName': _generateChannelName(),
      }),
    );

    return jsonDecode(res.body)['token'];
  }

  @override
  void dispose() {
    _cleanupAgoraEngine();
    super.dispose();
  }

  // Leaves the channel and releases resources
  Future<void> _cleanupAgoraEngine() async {
    await _engine.leaveChannel();
    await _engine.release();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agora Video Calling')),
      body: Stack(
        children: [
          Center(child: _remoteVideo()),
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 100,
              height: 150,
              child: Center(
                child: _localUserJoined
                    ? _localVideo()
                    : const CircularProgressIndicator(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Displays remote video view
  Widget _localVideo() {
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

  // Displays remote video view
  Widget _remoteVideo() {
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: _generateChannelName()),
        ),
      );
    } else {
      return const Text(
        'Waiting for remote user to join...',
        textAlign: TextAlign.center,
      );
    }
  }
}
