import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../utils/notathletes_auth_headers.dart';
import '../utils/uri_utils.dart';
import '../utils/theme/color_extensions.dart';
import '../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../widgets/buttons/opacity_button_widget_two.dart';
import '../urls.dart';

Future<bool> checkStripeSubscription({required String email}) async {
  try {
    final uri = Uri.parse(apiBaseUrl).resolve(checkClientAccessPath);
    final response = await http.post(
      uri,
      headers: notathletesAuthHeaders(),
      body: jsonEncode({'email': email}),
    );
    if (response.statusCode != 200) {
      return false;
    }
    final data = jsonDecode(response.body);
    return data is Map<String, dynamic> &&
        data['hasActiveSubscription'] == true;
  } catch (_) {
    return false;
  }
}

Future<bool> requireClientAccess({
  required BuildContext context,
  required String email,
  bool signOutOnFail = false,
  Future<void> Function()? onDenied,
}) async {
  final isAllowed = await checkStripeSubscription(email: email);
  if (isAllowed) return true;

  await _showClientAccessRequiredSheet(context);
  if (signOutOnFail && onDenied != null) {
    await onDenied();
  }
  return false;
}

Future<void> _showClientAccessRequiredSheet(BuildContext context) async {
  await showAppBottomSheet<void>(
    context: context,
    isScrollControlled: false,
    isDismissible: false,
    isDraggable: false,
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Complete your signup",
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 8),
          Text(
            "To use the app, complete the survey, set up your subscription, and book a consultation call. Then come back and sign in using the same email you used for payment.",
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.start,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: Builder(
              builder: (ctx) {
                final theme = Theme.of(ctx);
                final buttonColor =
                    theme.extension<TRKRColors>()?.vibrantAccent ??
                        theme.colorScheme.primary;
                return OpacityButtonWidgetTwo(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await openUrl(
                      context: ctx,
                      url: 'https://www.notathletes.com/survey',
                    );
                  },
                  label: "Open survey",
                  buttonColor: buttonColor,
                  showArrowRight: false,
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
