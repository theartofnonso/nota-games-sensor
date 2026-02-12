import 'dart:convert';

import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/notathletes_auth_headers.dart';
import '../../utils/dialog_utils.dart';
import '../../urls.dart';
import '../bottom_sheets/app_bottom_sheet.dart';
import '../buttons/opacity_button_widget_two.dart';

/// Client-only: section that contains the cancel membership action.
/// Same user journey as delete account (prompts and confirmation).
class UnsubscribeSection extends StatelessWidget {
  final VoidCallback onUnsubscribeTap;

  const UnsubscribeSection({
    super.key,
    required this.onUnsubscribeTap,
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
          onTap: onUnsubscribeTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.circleMinus,
                  size: 18,
                  color: contentColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Cancel my membership',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: contentColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: contentColor.withValues(alpha: 0.6),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

const String _unsubscribeConfirmationPhrase = 'Cancel my membership';

/// Runs the subscription cancellation flow: two confirmation sheets, then
/// Stripe cancel → sign out and cleanup (no account/data deletion).
Future<void> requestSubscriptionCancellation(
  BuildContext context, {
  required void Function(bool) setLoading,
}) async {
  final proceeded = await showAppBottomSheet<bool>(
    context: context,
    isScrollControlled: false,
    isDismissible: true,
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Cancel membership',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 8),
          Text(
            'Your subscription will be cancelled. You will be signed out and will lose access to the app until you subscribe again.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OpacityButtonWidgetTwo(
              onPressed: () => Navigator.of(context).pop(true),
              label: 'Proceed',
              buttonColor: Colors.red,
            ),
          ),
        ],
      ),
    ),
  );
  if (proceeded != true) return;

  final confirmed = await _showUnsubscribeConfirmSheet(context);
  if (confirmed != true) return;

  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) return;

  const defaultErrorMessage =
      'Something went wrong. Please try again or contact support at notathletes.com.';

  setLoading(true);

  try {
    final stripeUri =
        Uri.parse(stripeBaseUrl).resolve(stripeSubscriptionCancelPath);
    final stripeResponse = await http.post(
      stripeUri,
      headers: notathletesAuthHeaders(),
      body: jsonEncode({'userId': userId}),
    );
    if (stripeResponse.statusCode != 200 && stripeResponse.statusCode != 204) {
      if (!context.mounted) return;
      setLoading(false);
      showErrorBottomSheet(
        context: context,
        title: 'Could not cancel membership',
        message: _errorMessageFromBody(stripeResponse.body) ?? defaultErrorMessage,
      );
      return;
    }
  } catch (_) {
    if (!context.mounted) return;
    setLoading(false);
    showErrorBottomSheet(
      context: context,
      title: 'Could not cancel membership',
      message: defaultErrorMessage,
    );
    return;
  }

  // Sign out and cleanup (same as delete flow, but no Agora/Supabase deletion)
  if (!context.mounted) return;
  setLoading(false);
  try {
    await ChatClient.getInstance.logout(true);
  } catch (_) {}
  await Supabase.instance.client.auth.signOut();
}

Future<bool?> _showUnsubscribeConfirmSheet(BuildContext context) async {
  String typed = '';
  return showAppBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    child: StatefulBuilder(
      builder: (context, setSheetState) {
        final matches = typed.trim() == _unsubscribeConfirmationPhrase;
        final viewInsets = MediaQuery.of(context).viewInsets;
        return Padding(
          padding: const EdgeInsets.all(26).add(EdgeInsets.only(
            bottom: viewInsets.bottom,
          )),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To confirm, type "$_unsubscribeConfirmationPhrase" below.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.start,
              ),
              const SizedBox(height: 16),
              TextField(
                onChanged: (value) => setSheetState(() => typed = value),
                decoration: InputDecoration(
                  hintText: _unsubscribeConfirmationPhrase,
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
                  label: 'Cancel my membership',
                  buttonColor: Colors.red,
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
