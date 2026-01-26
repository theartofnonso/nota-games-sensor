import 'dart:async';
import 'dart:convert';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/agora_video_bootstrap.dart';
import '../../utils/agora_chat_utils.dart';
import '../../utils/dialog_utils.dart';
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
  RtcEngine? _engine;
  bool _localUserJoined = false;
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  int? _remoteUid;
  late final String _channelName;
  bool _permissionsGranted = false;

  @override
  void initState() {
    super.initState();
    // Generate unique channel name from current user and target user IDs
    _channelName = _generateChannelName();
    // Check permissions first, then start video calling
    _checkPermissions();
  }

  String _generateChannelName() {
    // Create a deterministic channel name from both user IDs
    // Sort IDs to ensure both users get the same channel name
    final currentUserId = Supabase.instance.client.auth.currentUser?.id ?? '';
    final userIds = [currentUserId, widget.targetUserId]..sort();
    return 'call_${userIds.join('_')}';
  }

  @override
  void dispose() {
    if (_engine != null) {
      unawaited(AgoraVideoBootstrap.releaseEngine(_engine));
    }
    super.dispose();
  }

  /// Check permissions first (following Agora's documentation pattern)
  Future<void> _checkPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final microphoneStatus = await Permission.microphone.status;

    final allGranted = cameraStatus.isGranted && microphoneStatus.isGranted;

    if (allGranted) {
      setState(() => _permissionsGranted = true);
      _startVideoCalling();
    } else {
      _requestPermissions();
    }
  }

  /// Request permissions (following Agora's documentation pattern)
  Future<void> _requestPermissions() async {
    final permissions =
        await [Permission.microphone, Permission.camera].request();

    final cameraStatus = permissions[Permission.camera];
    final microphoneStatus = permissions[Permission.microphone];

    final allGranted = permissions.values.every((status) => status.isGranted);

    if (!allGranted) {
      if (mounted) {
        final cameraDenied = cameraStatus?.isDenied ?? false;
        final micDenied = microphoneStatus?.isDenied ?? false;
        final cameraPermanentlyDenied =
            cameraStatus?.isPermanentlyDenied ?? false;
        final micPermanentlyDenied =
            microphoneStatus?.isPermanentlyDenied ?? false;

        String message =
            'Camera and microphone permissions are required for video calls.';
        if (cameraPermanentlyDenied || micPermanentlyDenied) {
          message += '\n\nPlease enable them in Settings > Not Athletes.';
        } else if (cameraDenied || micDenied) {
          message += '\n\nPlease grant permissions when prompted.';
        }

        showErrorBottomSheet(
          context: context,
          message: message,
        );
        Navigator.of(context).pop();
      }
      return;
    }

    // Permissions granted, proceed with video call
    setState(() => _permissionsGranted = true);
    _startVideoCalling();
  }

  /// Start video calling following Agora's exact workflow:
  /// 1. Initialize engine
  /// 2. Setup event handlers (BEFORE enabling video)
  /// 3. Enable video
  /// 4. Start preview
  /// 5. Setup local video
  /// 6. Join channel
  Future<void> _startVideoCalling() async {
    try {
      // Step 1: Initialize the Agora Engine
      _engine = await AgoraVideoBootstrap.createEngine();

      // Step 2: Setup event handlers (BEFORE enabling video, as per Agora docs)
      _setupEventHandlers();

      // Step 3: Enable video module
      await _engine!.enableVideo();

      // Step 4: Start preview (enables local video preview)
      await _engine!.startPreview();

      // Step 5: Setup local video (must be done after startPreview)
      _setupLocalVideo();

      // Step 6: Join channel
      await _joinChannel();
    } catch (e) {
      if (mounted) {
        showErrorBottomSheet(
          context: context,
          message: 'Failed to start video call: ${e.toString()}',
        );
        Navigator.of(context).pop();
      }
    }
  }

  /// Setup event handlers (must be called BEFORE enabling video, as per Agora docs)
  void _setupEventHandlers() {
    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          if (mounted) {
            setState(() {
              _localUserJoined = true;
            });
          }
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          if (mounted) {
            setState(() {
              _remoteUid = remoteUid;
            });
            // Setup remote video when user joins
            _setupRemoteVideo(remoteUid);
          }
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          if (mounted) {
            setState(() {
              _remoteUid = null;
            });
          }
        },
        onError: (ErrorCodeType err, String msg) {
          if (mounted) {
            showErrorBottomSheet(
              context: context,
              message: 'Video call error (${err.value}): $msg',
            );
          }
        },
      ),
    );
  }

  /// Setup local video view (following Agora's documentation pattern)
  void _setupLocalVideo() {
    // Local video is set up via AgoraVideoView widget in the build method
    // This method ensures the view is ready after preview starts
    if (mounted) {
      setState(() {
        // Trigger rebuild to show local video
      });
    }
  }

  /// Setup remote video view (following Agora's documentation pattern)
  void _setupRemoteVideo(int remoteUid) {
    // Remote video is set up via AgoraVideoView widget in the build method
    // This method ensures the view is ready when remote user joins
    if (mounted) {
      setState(() {
        // Trigger rebuild to show remote video
      });
    }
  }

  Future<void> _joinChannel() async {
    final token = await _resolveVideoToken();
    if (token == null || token.isEmpty) {
      throw Exception('Video call token is not available.');
    }
    final currentUserId = await _getCurrentUserId();
    if (currentUserId == null) {
      throw Exception('No user ID available.');
    }
    await _engine!.joinChannel(
      token: token,
      channelId: _channelName,
      uid: 0,
      options: const ChannelMediaOptions(
        autoSubscribeVideo: true,
        autoSubscribeAudio: true,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ),
    );
  }

  Future<String?> _getCurrentUserId() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      return user?.id;
    } catch (_) {
      return null;
    }
  }

  Future<String?> _resolveVideoToken() async {
    try {
      final currentUserId = await _getCurrentUserId();
      if (currentUserId == null) {
        throw Exception('No current user ID available');
      }

      final agoraUserId = toAgoraUsername(currentUserId);
      final uri = Uri.parse(agoraBaseUrl).resolve(agoraVideoTokenPath);
      final response = await http.post(
        uri,
        headers: const {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': agoraUserId,
          'channelName': _channelName,
        }),
      );
      if (response.statusCode != 200) {
        throw Exception(
            'Token API returned ${response.statusCode}: ${response.body}');
      }
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        final token = data['token'] as String?;
        if (token == null || token.isEmpty) {
          throw Exception('Token is null or empty');
        }
        return token;
      }
      throw Exception('Invalid token response format');
    } catch (e) {
      // Re-throw to be caught by _initializeVideoCall
      rethrow;
    }
  }

  void _toggleMute() {
    if (_engine == null || !_localUserJoined) return;
    try {
      _engine!.muteLocalAudioStream(!_isMuted);
      setState(() => _isMuted = !_isMuted);
    } catch (e) {
      // Silently handle error
    }
  }

  void _toggleVideo() {
    if (_engine == null || !_localUserJoined) return;
    try {
      _engine!.muteLocalVideoStream(!_isVideoEnabled);
      setState(() => _isVideoEnabled = !_isVideoEnabled);
    } catch (e) {
      // Silently handle error
    }
  }

  Future<void> _endCall() async {
    setState(() {
      _localUserJoined = false;
      _remoteUid = null;
    });
    // Cleanup following Agora's documentation pattern: stopPreview -> leaveChannel -> release
    await AgoraVideoBootstrap.releaseEngine(_engine);
    _engine = null;
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Video views - full screen edge to edge
          Positioned.fill(
            child: _buildVideoViews(),
          ),
          // Controls overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildControls(theme, isDarkMode),
          ),
          // Header
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildHeader(theme, isDarkMode),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoViews() {
    if (_engine == null || !_permissionsGranted) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth > 0 ? constraints.maxWidth : 400.0;
        final h = constraints.maxHeight > 0 ? constraints.maxHeight : 600.0;
        return Stack(
          children: [
            // Remote video (full screen)
            SizedBox(
              width: w,
              height: h,
              child: _remoteVideo(width: w, height: h),
            ),
            // Local video (preview in corner)
            Align(
              alignment: Alignment.topLeft,
              child: Container(
                width: 100,
                height: 150,
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _localVideo(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _localVideo() {
    if (_engine == null) {
      return const SizedBox.shrink();
    }
    return AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine!,
        canvas: const VideoCanvas(
          uid: 0,
          renderMode: RenderModeType.renderModeFit,
        ),
      ),
    );
  }

  Widget _remoteVideo({required double width, required double height}) {
    if (_remoteUid != null) {
      return SizedBox(
        width: width,
        height: height,
        child: AgoraVideoView(
          controller: VideoViewController.remote(
            rtcEngine: _engine!,
            canvas: VideoCanvas(
              uid: _remoteUid!,
              renderMode: RenderModeType.renderModeFit,
            ),
            connection: RtcConnection(channelId: _channelName),
          ),
        ),
      );
    }
    return Center(
      child: Text(
        _localUserJoined
            ? 'Waiting for remote user to join...'
            : 'Connecting...',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.grey[400],
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.black.withValues(alpha: 0.7),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.targetName ?? 'Video Call',
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.white),
            ),
          ),
          if (_localUserJoined)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'Connected',
                style: TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls(ThemeData theme, bool isDarkMode) {
    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 32,
        bottom: MediaQuery.of(context).padding.bottom + 32,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute button
          _buildControlButton(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            label: _isMuted ? 'Unmute' : 'Mute',
            onPressed: _toggleMute,
            backgroundColor:
                _isMuted ? Colors.red : Colors.white.withValues(alpha: 0.2),
            iconColor: Colors.white,
          ),
          // Video toggle
          _buildControlButton(
            icon: _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
            label: _isVideoEnabled ? 'Video Off' : 'Video On',
            onPressed: _toggleVideo,
            backgroundColor: _isVideoEnabled
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.red,
            iconColor: Colors.white,
          ),
          // End call
          _buildControlButton(
            icon: Icons.call_end,
            label: 'End',
            onPressed: _endCall,
            backgroundColor: Colors.red,
            iconColor: Colors.white,
            size: 56,
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required Color iconColor,
    double size = 48,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: backgroundColor,
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: Icon(icon, color: iconColor),
            onPressed: onPressed,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ],
    );
  }
}
