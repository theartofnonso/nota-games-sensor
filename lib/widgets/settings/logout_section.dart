import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Logout entry for both clients and coaches.
/// Same visual style as delete account section.
class LogoutSection extends StatelessWidget {
  final VoidCallback onLogoutTap;

  const LogoutSection({
    super.key,
    required this.onLogoutTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final surfaceOpacity = theme.brightness == Brightness.dark
        ? onSurface.withValues(alpha: 0.08)
        : onSurface.withValues(alpha: 0.06);
    final contentColor = onSurface.withValues(alpha: 0.75);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: surfaceOpacity,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onLogoutTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.arrowRightFromBracket,
                  size: 18,
                  color: contentColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Log out',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: contentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Signs out the user from Agora Chat and Supabase.
Future<void> performLogout() async {
  try {
    await ChatClient.getInstance.logout(true);
  } catch (_) {}
  await Supabase.instance.client.auth.signOut();
}
