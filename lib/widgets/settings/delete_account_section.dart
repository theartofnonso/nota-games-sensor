import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/chat_bootstrap_service.dart';
import '../../utils/notathletes_auth_headers.dart';
import '../../utils/dialog_utils.dart';
import '../../urls.dart';
import '../bottom_sheets/app_bottom_sheet.dart';
import '../buttons/opacity_button_widget_two.dart';

/// Client-only: danger-zone section that contains the delete account action.
/// Visually separated so the entry point is clear and intentional.
class DeleteAccountSection extends StatelessWidget {
  final VoidCallback onDeleteTap;

  const DeleteAccountSection({
    super.key,
    required this.onDeleteTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final surfaceOpacity = theme.brightness == Brightness.dark
        ? onSurface.withValues(alpha: 0.08)
        : onSurface.withValues(alpha: 0.06);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: surfaceOpacity,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onDeleteTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.userMinus,
                  size: 18,
                  color: Colors.red,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Delete my account',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.red,
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

const String _deleteAccountConfirmationPhrase = 'Delete my account';

/// Matches [confirmLogoutBottomSheet] and other action sheets (padding + type scale).
const EdgeInsets _deleteSheetPadding = EdgeInsets.all(26);

/// Runs the full account deletion flow: two confirmation sheets, then
/// Agora → Supabase delete → sign out. Calls [setLoading] with
/// true/false so the parent can show a loading overlay.
Future<void> requestAccountDeletion(
  BuildContext context, {
  required void Function(bool) setLoading,
}) async {
  final proceeded = await showAppActionBottomSheet<bool>(
    context: context,
    isDismissible: true,
    child: Padding(
      padding: _deleteSheetPadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Delete account',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 8),
          Text(
            'Your account and all associated data (workouts, plans, nutrition logs) will be permanently deleted. This cannot be undone.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OpacityButtonWidgetTwo(
              onPressed: () => Navigator.of(context).pop(true),
              label: 'Proceed',
              buttonColor: Colors.red,
              showArrowRight: false,
            ),
          ),
        ],
      ),
    ),
  );
  if (proceeded != true) return;

  if (!context.mounted) return;
  final confirmed = await _showDeleteAccountConfirmSheet(context);
  if (confirmed != true) return;

  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;

  const defaultErrorMessage =
      'Something went wrong. Please try again or contact support at notathletes.com.';

  setLoading(true);

  // 1. Agora
  try {
    final agoraUri = Uri.parse(agoraBaseUrl).resolve(agoraUserDeletePath);
    final agoraResponse = await http.post(
      agoraUri,
      headers: notathletesAuthHeaders(),
      body: jsonEncode({'userId': userId}),
    );
    if (agoraResponse.statusCode != 200 && agoraResponse.statusCode != 204) {
      if (!context.mounted) return;
      setLoading(false);
      showErrorBottomSheet(
        context: context,
        title: 'Could not delete account',
        message: _errorMessageFromBody(agoraResponse.body) ?? defaultErrorMessage,
      );
      return;
    }
  } catch (_) {
    if (!context.mounted) return;
    setLoading(false);
    showErrorBottomSheet(
      context: context,
      title: 'Could not delete account',
      message: defaultErrorMessage,
    );
    return;
  }

  // 2. Supabase
  try {
    final uri = Uri.parse(apiNotathletesBaseUrl).resolve(accountDeletionPath);
    final response = await http.post(
      uri,
      headers: notathletesAuthHeaders(),
      body: jsonEncode({'userId': userId}),
    );
    if (!context.mounted) return;
    setLoading(false);
    if (response.statusCode != 200 && response.statusCode != 204) {
      showErrorBottomSheet(
        context: context,
        title: 'Could not delete account',
        message: _errorMessageFromBody(response.body) ?? defaultErrorMessage,
      );
      return;
    }
  } catch (_) {
    if (!context.mounted) return;
    setLoading(false);
    showErrorBottomSheet(
      context: context,
      title: 'Could not delete account',
      message: defaultErrorMessage,
    );
    return;
  }

  // 3. Sign out (clear unread + Agora session, then Supabase)
  if (!context.mounted) return;
  setLoading(false);
  await ChatBootstrapService.logoutAgoraChat();
  await Supabase.instance.client.auth.signOut();
}

Future<bool?> _showDeleteAccountConfirmSheet(BuildContext context) async {
  String typed = '';
  return showAppBottomSheet<bool>(
    context: context,
    isDraggable: false,
    isScrollControlled: true,
    isDismissible: true,
    child: StatefulBuilder(
      builder: (context, setSheetState) {
        final matches = typed.trim() == _deleteAccountConfirmationPhrase;
        return Padding(
          padding: _deleteSheetPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Confirm deletion',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.start,
              ),
              const SizedBox(height: 8),
              Text(
                'To confirm, type "$_deleteAccountConfirmationPhrase" below.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
                textAlign: TextAlign.start,
              ),
              const SizedBox(height: 12),
              TextField(
                style: Theme.of(context).textTheme.bodyLarge,
                onChanged: (value) => setSheetState(() => typed = value),
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  hintText: _deleteAccountConfirmationPhrase,
                  hintStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.38),
                      ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OpacityButtonWidgetTwo(
                  onPressed: matches
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  label: 'Delete my account',
                  buttonColor: Colors.red,
                  showArrowRight: false,
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

String? _errorMessageFromBody(String body) {
  if (body.isEmpty) return null;
  try {
    final decoded = jsonDecode(body) as Map<String, dynamic>?;
    final err = decoded?['error'] ?? decoded?['message'];
    return err?.toString();
  } catch (_) {
    return null;
  }
}
