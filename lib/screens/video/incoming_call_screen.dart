import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

import 'video_call_screen.dart';

/// Shown when the user receives an incoming video call (from FCM push).
/// Displays caller name, plays ringtone, offers Answer/Decline.
class IncomingCallScreen extends StatefulWidget {
  final String callerId;
  final String callerName;
  final String channelName;

  const IncomingCallScreen({
    super.key,
    required this.callerId,
    required this.callerName,
    required this.channelName,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  Timer? _timeoutTimer;
  bool _answered = false;

  @override
  void initState() {
    super.initState();
    FlutterRingtonePlayer().playRingtone();
    _timeoutTimer = Timer(const Duration(seconds: 45), _onTimeout);
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _stopRingtone();
    super.dispose();
  }

  void _stopRingtone() {
    try {
      FlutterRingtonePlayer().stop();
    } catch (_) {}
  }

  void _onTimeout() {
    if (!mounted || _answered) return;
    _stopRingtone();
    Navigator.of(context).pop();
  }

  Future<void> _handleAnswer() async {
    if (_answered) return;
    _answered = true;
    _timeoutTimer?.cancel();
    _stopRingtone();
    if (!mounted) return;
    Navigator.of(context).pop(); // Dismiss incoming call screen
    if (!mounted) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        fullscreenDialog: true,
        opaque: true,
        pageBuilder: (_, __, ___) => VideoCallScreen(
          targetUserId: widget.callerId,
          targetUserName: widget.callerName,
          channelName: widget.channelName, // From FCM push
        ),
        transitionsBuilder: (_, animation, __, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          final tween = Tween(begin: begin, end: end)
              .chain(CurveTween(curve: Curves.easeOutCubic));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  void _handleDecline() {
    if (_answered) return;
    _answered = true;
    _timeoutTimer?.cancel();
    _stopRingtone();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        widget.callerName.trim().isNotEmpty ? widget.callerName : 'Someone';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.25),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Spacer(),
                    const CircleAvatar(
                      radius: 56,
                      backgroundColor: Colors.white12,
                      child: Icon(
                        Icons.person,
                        size: 64,
                        color: Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Incoming video call',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _CallActionButton(
                          icon: Icons.call_end,
                          label: 'Decline',
                          backgroundColor: Colors.red,
                          onPressed: _handleDecline,
                        ),
                        _CallActionButton(
                          icon: Icons.videocam,
                          label: 'Answer',
                          backgroundColor: Colors.green,
                          onPressed: _handleAnswer,
                        ),
                      ],
                    ),
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final VoidCallback onPressed;

  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.backgroundColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: backgroundColor,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 72,
              height: 72,
              child: Icon(icon, color: Colors.white, size: 36),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
