import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/theme/color_extensions.dart';
import 'founder_coach_email.dart';
import '../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../widgets/buttons/opacity_button_widget_two.dart';

/// True when [email] matches a row in [public.coaches] and either `active` is true
/// or the email is [isFounderCoachEmail] (`@ware.health`) so hidden coaches can sign in.
Future<bool> checkCoachAccess(String email) async {
  try {
    final normalized = email.trim().toLowerCase();
    final record =
        await Supabase.instance.client
            .from('coaches')
            .select('email, name, active')
            .eq('email', normalized)
            .maybeSingle();
    if (record == null) return false;
    final active = record['active'] as bool? ?? false;
    if (active) return true;
    return isFounderCoachEmail(normalized);
  } catch (_) {
    return false;
  }
}

/// Requires coach access. If the email is not in the coaches table, shows
/// the access required sheet and optionally signs them out.
Future<bool> requireCoachAccess({
  required BuildContext context,
  required String email,
  bool signOutOnFail = false,
  Future<void> Function()? onDenied,
}) async {
  final canProceed = await checkCoachAccess(email);
  if (canProceed) return true;

  if (!context.mounted) return false;
  await _showCoachAccessRequiredSheet(context);
  if (signOutOnFail && onDenied != null) {
    await onDenied();
  }
  return false;
}

Future<void> _showCoachAccessRequiredSheet(BuildContext context) async {
  await showAppActionBottomSheet<void>(
    context: context,
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Coach access only",
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 8),
          Text(
            "Only Not Athletes coaches can train users with this app. If you're a coach, please contact support to get access.",
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OpacityButtonWidgetTwo(
              onPressed: () {
                Navigator.of(context).pop();
              },
              label: "Got it",
              buttonColor: Theme.of(context).colors.vibrantAccent,
            ),
          ),
        ],
      ),
    ),
  );
}
