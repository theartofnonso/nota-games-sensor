import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app_flavor.dart';
import '../../repositories/supabase/supabase_coaches_repository.dart';
import '../../widgets/coach/coach_profile_photo_backplate.dart';

/// Full-screen UI while the caller waits for [sendIncomingCallNotification] /
/// setup. Matches [IncomingCallScreen] visuals: callee photo or blurred scrim,
/// gradient, title — only **Cancel** (end call).
class OutgoingCallScreen extends StatefulWidget {
  /// Display name of the person being called (coach name or client name).
  final String calleeName;

  /// When the **client** calls their coach, pass coach’s Supabase user id to
  /// load profile photo; omit for coach → client (no client photo in app).
  final String? coachIdForProfilePhoto;

  /// Called before this route is popped (user tapped Cancel).
  final VoidCallback? onCancel;

  const OutgoingCallScreen({
    super.key,
    required this.calleeName,
    this.coachIdForProfilePhoto,
    this.onCancel,
  });

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen> {
  String? _calleePhotoUrl;

  String? get _effectivePhotoUrl {
    final u = _calleePhotoUrl?.trim();
    return (u != null && u.isNotEmpty) ? u : null;
  }

  @override
  void initState() {
    super.initState();
    final coachId = widget.coachIdForProfilePhoto?.trim();
    if (coachId != null && coachId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadCoachPhoto(coachId));
    }
  }

  Future<void> _loadCoachPhoto(String coachId) async {
    try {
      final coach = await SupabaseCoachesRepository().fetchCoachById(coachId);
      if (!mounted) return;
      final url = coach?.profileImageUrl?.trim();
      if (url != null && url.isNotEmpty) {
        setState(() => _calleePhotoUrl = url);
      }
    } catch (_) {
      // Keep blurred fallback
    }
  }

  String get _headerTitle {
    final trimmed = widget.calleeName.trim();
    if (trimmed.isEmpty) {
      return AppConfig.isClient ? 'Coach' : 'Client';
    }
    if (AppConfig.isClient) {
      return 'Coach $trimmed';
    }
    return trimmed;
  }

  void _handleCancel() {
    widget.onCancel?.call();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final photoUrl = _effectivePhotoUrl;
    final hasPhoto = photoUrl != null;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          fit: StackFit.expand,
          children: [
            if (photoUrl != null)
              Positioned.fill(
                child: CoachProfilePhotoBackplate.behind(
                  context,
                  Image.network(
                    photoUrl,
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    errorBuilder: (_, __, ___) => ColoredBox(
                      color: CoachProfilePhotoBackplate.plateColor(context),
                    ),
                    loadingBuilder: (ctx, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return ColoredBox(
                        color: CoachProfilePhotoBackplate.plateColor(ctx)
                            .withValues(alpha: 0.92),
                        child: const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black26,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
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
                    const SizedBox(height: 12),
                    Text(
                      'Calling…',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    _OutgoingCallActionButton(
                      icon: Icons.call_end,
                      label: 'Cancel',
                      backgroundColor: Colors.red,
                      onPressed: _handleCancel,
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

class _OutgoingCallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color backgroundColor;
  final VoidCallback onPressed;

  const _OutgoingCallActionButton({
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
