import 'package:flutter/material.dart';

import '../../app_flavor.dart';

/// Initials for the chat peer (other party), matching [ChatScreen] app bar logic.
String chatPeerInitialsFromName(String rawName) {
  final trimmed = rawName.trim();
  if (AppConfig.isCoach) {
    // Coach app: peer is the client
    if (trimmed.isEmpty) return 'C';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      final s = parts.first;
      if (s.isEmpty) return 'C';
      return s.substring(0, s.length.clamp(0, 2)).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  // Client app: peer is the coach
  if (trimmed.isEmpty) return 'U';
  return trimmed[0].toUpperCase();
}

/// Rounded gradient badge with peer initials — same look as the chat screen header.
class ChatPeerInitialsBadge extends StatelessWidget {
  const ChatPeerInitialsBadge({
    super.key,
    required this.peerName,
    this.size = 36,
    /// Dark-backdrop styling (e.g. incoming call overlay) to match chat dark header.
    this.onDarkBackdrop = false,
  });

  final String peerName;
  final double size;
  final bool onDarkBackdrop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode =
        onDarkBackdrop || theme.brightness == Brightness.dark;
    final initials = chatPeerInitialsFromName(peerName);
    if (initials.isEmpty) {
      return SizedBox(width: size, height: size);
    }

    final borderRadius = size * (6 / 36);
    final fontSize = (theme.textTheme.labelLarge?.fontSize ?? 14) * (size / 36);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (isDarkMode ? Colors.white : Colors.black)
                .withValues(alpha: 0.18),
            (isDarkMode ? Colors.white : Colors.black)
                .withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Text(
        initials,
        style: theme.textTheme.labelLarge?.copyWith(
          color: isDarkMode ? Colors.white : Colors.black,
          fontWeight: FontWeight.w700,
          fontSize: fontSize,
        ),
      ),
    );
  }
}
