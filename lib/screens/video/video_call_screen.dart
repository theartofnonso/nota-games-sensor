import 'dart:convert';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/config/video_config.dart';

import '../../utils/agora_chat_utils.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/notathletes_auth_headers.dart';
import '../../urls.dart';

class VideoCallScreen extends StatefulWidget {
  final String targetUserId;

  const VideoCallScreen({
    super.key,
    required this.targetUserId,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late final RtcEngine _engine;

  bool _localUserJoined = false;
  int? _remoteUid;
  bool _isMuted = false;
  bool _isCameraEnabled = true;

  @override
  void initState() {
    super.initState();
    _startVideoCalling();
  }

  /* --------------------------- INIT FLOW --------------------------- */

  Future<void> _startVideoCalling() async {
    await _requestPermissions();
    await _initializeAgora();
    await _setupLocalVideo();
    _registerEventHandlers();
    await _joinChannel();
  }

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.microphone,
      Permission.camera,
    ].request();

    if (statuses[Permission.microphone] != PermissionStatus.granted ||
        statuses[Permission.camera] != PermissionStatus.granted) {
      throw StateError('Camera or microphone permission not granted');
    }
  }

  Future<void> _initializeAgora() async {
    _engine = createAgoraRtcEngine();
    await _engine.initialize(
      const RtcEngineContext(
        appId: VideoConfig.agoraAppId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
  }

  Future<void> _setupLocalVideo() async {
    await _engine.enableVideo();
    await _engine.startPreview();
  }

  void _registerEventHandlers() {
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (_, __) {
          setState(() => _localUserJoined = true);
        },
        onUserJoined: (_, remoteUid, __) {
          setState(() => _remoteUid = remoteUid);
        },
        onUserOffline: (_, __, ___) {
          setState(() => _remoteUid = null);
        },
        onError: (err, msg) {
          debugPrint('Agora error: $err, $msg');
          if (err == ErrorCodeType.errInvalidToken) {
            _engine.leaveChannel();
            if (mounted) {
              showBottomSheetWithSingleAction(
                context: context,
                title: 'Unable to join call',
                description:
                    'The connection could not be established. Please try again.',
                action: () {
                  Navigator.of(context).pop(); // close sheet
                  if (mounted) Navigator.of(context).pop(); // close video screen
                },
                actionLabel: 'Got it',
                isDismissible: false,
              );
            }
          }
        },
      ),
    );
  }

  /* --------------------------- JOIN CHANNEL --------------------------- */

  Future<void> _joinChannel() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) throw StateError('User not authenticated');

    final channelName = _generateChannelName();
    final token = await _fetchAgoraToken(channelName, userId);

    if (token == null || token.isEmpty) {
      throw StateError('Failed to retrieve Agora token');
    }

    final agoraUserAccount = toAgoraUsername(userId);
    await _engine.joinChannelWithUserAccount(
      token: token,
      channelId: channelName,
      userAccount: agoraUserAccount,
      options: const ChannelMediaOptions(
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
      ),
    );
  }

  /* --------------------------- HELPERS --------------------------- */

  String _generateChannelName() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final ids = [currentUserId, widget.targetUserId]..sort();
    final half = (64 - 6) ~/ 2; // 64 max - 'call__' = 58, /2 = 29 each
    final a = ids[0].replaceAll('-', '').substring(0, half.clamp(0, 32));
    final b = ids[1].replaceAll('-', '').substring(0, half.clamp(0, 32));
    return 'call_${a}_$b';
  }

  /// [supabaseUserId] is the raw auth user id; backend derives Agora username for the token.
  Future<String?> _fetchAgoraToken(
      String channelName, String supabaseUserId) async {
    final res = await http.post(
      Uri.parse(agoraBaseUrl).resolve(agoraVideoTokenPath),
      headers: notathletesAuthHeaders(),
      body: jsonEncode({
        'channelName': channelName,
        'userId': supabaseUserId,
      }),
    );

    if (res.statusCode != 200) return null;
    return jsonDecode(res.body)['token'] as String?;
  }

  /* --------------------------- CLEANUP --------------------------- */

  @override
  void dispose() {
    _engine.leaveChannel();
    _engine.release();
    super.dispose();
  }

  /* --------------------------- CONTROL METHODS --------------------------- */

  Future<void> _toggleMute() async {
    await _engine.muteLocalAudioStream(!_isMuted);
    setState(() => _isMuted = !_isMuted);
  }

  Future<void> _toggleCamera() async {
    final newState = !_isCameraEnabled;

    // Use enableLocalVideo to turn capture on/off. Avoids updateChannelMediaOptions
    // which can throw AgoraRtcException(-8) when channel state doesn't allow it.
    await _engine.enableLocalVideo(newState);

    setState(() => _isCameraEnabled = newState);
  }

  Future<void> _switchCamera() async {
    await _engine.switchCamera();
  }

  Future<void> _endCall() async {
    await _engine.leaveChannel();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  /* --------------------------- UI --------------------------- */

  static const double _videoPadding = 18;
  static const double _videoRadius = 18;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Split screen: top half remote, bottom half local (with padding and rounded corners)
          Padding(
            padding: const EdgeInsets.all(_videoPadding),
            child: Column(
              children: [
                // Remote video (top half)
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_videoRadius),
                    child: _remoteVideoView(),
                  ),
                ),
                const SizedBox(height: 12),
                // Local video (bottom half)
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(_videoRadius),
                    child: _isCameraEnabled && _localUserJoined
                        ? _localVideoView()
                        : Container(
                            color: Colors.black,
                            child: const Center(
                              child: Icon(
                                Icons.person,
                                color: Colors.white54,
                                size: 60,
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
          // Control buttons at bottom
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: _controlButtons(),
          ),
        ],
      ),
    );
  }

  Widget _localVideoView() {
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

  Widget _remoteVideoView() {
    if (_remoteUid == null) {
      return const Center(
        child: Text(
          'Waiting for the other user to join…',
          style: TextStyle(color: Colors.white),
          textAlign: TextAlign.center,
        ),
      );
    }

    return AgoraVideoView(
      controller: VideoViewController.remote(
        rtcEngine: _engine,
        canvas: VideoCanvas(uid: _remoteUid),
        connection: RtcConnection(channelId: _generateChannelName()),
      ),
    );
  }

  Widget _controlButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Mute button
        _ControlButton(
          icon: _isMuted ? Icons.mic_off : Icons.mic,
          onPressed: _toggleMute,
          backgroundColor:
              _isMuted ? Colors.red : Colors.white.withValues(alpha: 0.2),
        ),
        const SizedBox(width: 16),
        // Camera toggle button
        _ControlButton(
          icon: _isCameraEnabled ? Icons.videocam : Icons.videocam_off,
          onPressed: _toggleCamera,
          backgroundColor: _isCameraEnabled
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.red,
        ),
        const SizedBox(width: 16),
        // Switch camera button
        _ControlButton(
          icon: Icons.flip_camera_ios,
          onPressed: _switchCamera,
          backgroundColor: Colors.white.withValues(alpha: 0.2),
        ),
        const SizedBox(width: 16),
        // End call button
        _ControlButton(
          icon: Icons.call_end,
          onPressed: _endCall,
          backgroundColor: Colors.red,
        ),
      ],
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color backgroundColor;

  const _ControlButton({
    required this.icon,
    required this.onPressed,
    required this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: () {
          HapticFeedback.heavyImpact();
          onPressed();
        },
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 56,
          height: 56,
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}
