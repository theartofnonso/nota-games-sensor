import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/theme/color_extensions.dart';
import '../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../widgets/buttons/opacity_button_widget_two.dart';

/// Checks if an email exists in the coaches table.
Future<bool> checkCoachAccess(String email) async {
  try {
    final record = await Supabase.instance.client
        .from('coaches')
        .select('email, name')
        .eq('email', email)
        .maybeSingle();
    return record != null;
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

  await _showCoachAccessRequiredSheet(context);
  if (signOutOnFail && onDenied != null) {
    await onDenied();
  }
  return false;
}

Future<void> _showCoachAccessRequiredSheet(BuildContext context) async {
  await showAppBottomSheet<void>(
    context: context,
    isScrollControlled: false,
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
              showArrowRight: false,
            ),
          ),
        ],
      ),
    ),
  );
}
