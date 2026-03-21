import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bottom_sheets/app_bottom_sheet.dart';
import '../buttons/opacity_button_widget_two.dart';

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

/// Confirmation sheet (same pattern as delete-account first step). Returns true
/// if the user confirms they want to log out.
Future<bool> confirmLogoutBottomSheet(BuildContext context) async {
  final result = await showAppActionBottomSheet<bool>(
    context: context,
    isDismissible: true,
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Log out',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 8),
          Text(
            'You will be signed out on this device. Unsaved work may be lost. You can sign in again anytime.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OpacityButtonWidgetTwo(
              onPressed: () => Navigator.of(context).pop(true),
              label: 'Log out',
            ),
          ),
        ],
      ),
    ),
  );
  return result == true;
}

/// Shows [confirmLogoutBottomSheet], then signs out with loading callbacks.
Future<void> logoutWithConfirmation(
  BuildContext context, {
  required void Function(bool) setLoading,
}) async {
  final ok = await confirmLogoutBottomSheet(context);
  if (!ok || !context.mounted) return;
  setLoading(true);
  try {
    await performLogout();
  } finally {
    if (context.mounted) {
      setLoading(false);
    }
  }
}

/// Signs out the user from Agora Chat and Supabase.
Future<void> performLogout() async {
  try {
    await ChatClient.getInstance.logout(true);
  } catch (_) {}
  await Supabase.instance.client.auth.signOut();
}
