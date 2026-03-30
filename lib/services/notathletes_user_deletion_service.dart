import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/services/chat_bootstrap_service.dart';
import 'package:trainware/services/revenue_cat_bootstrap.dart';
import 'package:trainware/shared_prefs.dart';
import 'package:trainware/urls.dart';
import 'package:trainware/utils/notathletes_auth_headers.dart';

/// Result of [deleteNotathletesUser] (Agora + api.notathletes.com account delete).
class NotathletesUserDeletionOutcome {
  NotathletesUserDeletionOutcome._({required this.ok, this.errorMessage});

  final bool ok;
  final String? errorMessage;

  factory NotathletesUserDeletionOutcome.success() =>
      NotathletesUserDeletionOutcome._(ok: true);

  factory NotathletesUserDeletionOutcome.failure(String? message) =>
      NotathletesUserDeletionOutcome._(ok: false, errorMessage: message);
}

String? errorMessageFromNotathletesBody(String body) {
  if (body.isEmpty) return null;
  try {
    final decoded = jsonDecode(body) as Map<String, dynamic>?;
    final err = decoded?['error'] ?? decoded?['message'];
    return err?.toString();
  } catch (_) {
    return null;
  }
}

/// Same sequence as Settings → Delete account: Agora `POST /user/delete`, then
/// `POST /account/delete`. Agora **404** counts as success (no chat user yet).
Future<NotathletesUserDeletionOutcome> deleteNotathletesUser(
  String userId,
) async {
  const defaultError =
      'Something went wrong. Please try again or contact support at notathletes.com.';

  try {
    final agoraUri = Uri.parse(agoraBaseUrl).resolve(agoraUserDeletePath);
    final agoraResponse = await http.post(
      agoraUri,
      headers: notathletesAuthHeaders(),
      body: jsonEncode({'userId': userId}),
    );
    final agoraOk = agoraResponse.statusCode == 200 ||
        agoraResponse.statusCode == 204 ||
        agoraResponse.statusCode == 404;
    if (!agoraOk) {
      return NotathletesUserDeletionOutcome.failure(
        errorMessageFromNotathletesBody(agoraResponse.body) ?? defaultError,
      );
    }
  } catch (_) {
    return NotathletesUserDeletionOutcome.failure(defaultError);
  }

  try {
    final uri = Uri.parse(apiNotathletesBaseUrl).resolve(accountDeletionPath);
    final response = await http.post(
      uri,
      headers: notathletesAuthHeaders(),
      body: jsonEncode({'userId': userId}),
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      return NotathletesUserDeletionOutcome.failure(
        errorMessageFromNotathletesBody(response.body) ?? defaultError,
      );
    }
  } catch (_) {
    return NotathletesUserDeletionOutcome.failure(defaultError);
  }

  return NotathletesUserDeletionOutcome.success();
}

Future<void> _signOutAfterAccountDeletionBackendSuccess() async {
  if (AppConfig.isClient) {
    SharedPrefs().markClientPreAuthLandingPending();
  }
  await ChatBootstrapService.logoutAgoraChat();
  await RevenueCatBootstrap.logOutIfClient();
  await Supabase.instance.client.auth.signOut();
}

/// [deleteNotathletesUser], optional [afterBackendDelete] (e.g. close a modal), then
/// the same sign-out as Settings → Delete account (pre-auth landing, Agora, RevenueCat,
/// Supabase) so the client returns to the app start.
Future<NotathletesUserDeletionOutcome> deleteAccountAndSignOut({
  Future<void> Function()? afterBackendDelete,
}) async {
  final userId = Supabase.instance.client.auth.currentUser?.id;
  if (userId == null) {
    return NotathletesUserDeletionOutcome.failure('You are not signed in.');
  }

  final outcome = await deleteNotathletesUser(userId);
  if (!outcome.ok) return outcome;

  if (afterBackendDelete != null) {
    await afterBackendDelete();
  }

  await _signOutAfterAccountDeletionBackendSuccess();
  return NotathletesUserDeletionOutcome.success();
}
