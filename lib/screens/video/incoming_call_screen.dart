import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';

import '../../app_flavor.dart';
import 'video_call_screen.dart';

/// Incoming video call (FCM / deep link). The **callee** sees the **caller’s** photo when
/// [callerImageUrl] is present; otherwise the usual blurred scrim (no image).
class IncomingCallScreen extends StatefulWidget {
  final String callerId;
  final String callerName;
  final String channelName;

  /// Caller’s profile image URL from FCM (`callerImageUrl`). Omit or empty = no background photo.
  final String? callerImageUrl;

  const IncomingCallScreen({
    super.key,
    required this.callerId,
    required this.callerName,
    required this.channelName,
    this.callerImageUrl,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> {
  Timer? _timeoutTimer;
  bool _answered = false;

  String? get _callerPhotoUrl {
    final u = widget.callerImageUrl?.trim();
    return (u != null && u.isNotEmpty) ? u : null;
  }

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

  /// Centered title: client sees "Coach {name}", coach sees caller name.
  String get _headerTitle {
    final trimmed = widget.callerName.trim();
    if (trimmed.isEmpty) {
      return AppConfig.isClient ? 'Coach' : 'Someone';
    }
    if (AppConfig.isClient) {
      return 'Coach $trimmed';
    }
    return trimmed;
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = _callerPhotoUrl;
    final hasPhoto = photoUrl != null;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Full-bleed photo (iPhone-style) or blurred scrim fallback
            if (photoUrl != null)
              Positioned.fill(
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black87),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const ColoredBox(color: Colors.black87);
                  },
                ),
              )
            else
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.25),
                  ),
                ),
              ),

            // Readability scrim (stronger when photo is visible)
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: hasPhoto ? 0.5 : 0.35),
                        Colors.black.withValues(alpha: hasPhoto ? 0.2 : 0.12),
                        Colors.black.withValues(alpha: hasPhoto ? 0.75 : 0.45),
                      ],
                      stops: const [0.0, 0.42, 1.0],
                    ),
                  ),
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
                    Text(
                      _headerTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
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
