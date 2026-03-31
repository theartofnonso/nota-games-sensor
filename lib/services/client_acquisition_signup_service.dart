import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:trainware/logger.dart';
import 'package:trainware/urls.dart';

final _log = getLogger(className: 'ClientAcquisitionSignupService');

/// Result of [signupWithCoach] (pre-auth).
enum ClientAcquisitionSignupResult {
  /// Signed in via `refreshToken` (or `refresh_token`) in the response.
  success,
  /// Backend created the user but returned no session — user should **Sign In** (e.g. OTP).
  successSignInRequired,
  emailAlreadyExists,
  invalidRequest,
  serverError,
}

/// **POST** `{apiNotathletesBaseUrl}{clientCoachSignupPath}` (`/client-coach-signup`)
///
/// **Headers:** `Content-Type: application/json`
///
/// **Body (JSON, camelCase)**
/// ```json
/// { "fullName": "...", "email": "...", "coachId": "<uuid>" }
/// ```
///
/// **Success (200)** — with **mobile auto sign-in** (recommended):
/// ```json
/// { "success": true, "refreshToken": "<supabase_refresh_jwt>" }
/// ```
/// The app reads **`refreshToken`** first, then `refresh_token`, and nested `session` / `data` (see [_parseRefreshToken]).
/// If `success` is true but no refresh token is present → [ClientAcquisitionSignupResult.successSignInRequired]
/// (unexpected if the API always returns `refreshToken`).
///
/// **Failure (200 with success false or 4xx/5xx)**
/// ```json
/// { "success": false, "message": "Failed to create client and assign coach" }
/// ```
///
/// **400 / 422** with `{ "success": false, "message": "..." }` (e.g. missing `fullName`,
/// invalid email, invalid `coachId`, unknown coach) → [invalidRequest] (UI: fix input).
///
/// **409** or `success: false` message implying duplicate email → [emailAlreadyExists].
///
/// **Orphans:** Backend should use a transaction / compensation for Auth + `clients` + `coach_clients`.
Future<ClientAcquisitionSignupResult> signupWithCoach({
  required String email,
  required String fullName,
  required String coachId,
}) async {
  final uri = Uri.parse(apiNotathletesBaseUrl).resolve(clientCoachSignupPath);

  try {
    final response = await http
        .post(
          uri,
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'fullName': fullName.trim(),
            'email': email.trim(),
            'coachId': coachId.trim(),
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 409) {
      return ClientAcquisitionSignupResult.emailAlreadyExists;
    }

    Map<String, dynamic>? map;
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        map = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    // 400/422: validation (e.g. missing fullName, bad email, bad coachId, invalid coach).
    // Same shape as your API: { "success": false, "message": "..." }.
    if (response.statusCode == 400 || response.statusCode == 422) {
      if (map != null && map['success'] == false) {
        final msg = (map['message'] as String?)?.toLowerCase() ?? '';
        if (_looksLikeEmailExists(msg)) {
          return ClientAcquisitionSignupResult.emailAlreadyExists;
        }
        _log.w('client-coach-signup validation: ${map['message']}');
      }
      return ClientAcquisitionSignupResult.invalidRequest;
    }

    if (map != null) {
      final ok = map['success'];
      if (ok == false) {
        final msg = (map['message'] as String?)?.toLowerCase() ?? '';
        if (_looksLikeEmailExists(msg)) {
          return ClientAcquisitionSignupResult.emailAlreadyExists;
        }
        _log.w('client-coach-signup failed: ${map['message']}');
        return ClientAcquisitionSignupResult.serverError;
      }
      if (ok == true) {
        final refresh = _parseRefreshToken(map);
        if (refresh != null && refresh.isNotEmpty) {
          // API contract: `refreshToken` (camelCase) on success body — GoTrue accepts the JWT string.
          await Supabase.instance.client.auth.setSession(refresh);
          return ClientAcquisitionSignupResult.success;
        }
        _log.i('client-coach-signup: success without refreshToken; user must sign in');
        return ClientAcquisitionSignupResult.successSignInRequired;
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      _log.w(
        'client-coach-signup HTTP ${response.statusCode}: ${response.body}',
      );
      return ClientAcquisitionSignupResult.serverError;
    }

    _log.w('client-coach-signup: unexpected body ${response.body}');
    return ClientAcquisitionSignupResult.serverError;
  } catch (e, st) {
    _log.w('client-coach-signup failed', error: e, stackTrace: st);
    return ClientAcquisitionSignupResult.serverError;
  }
}

bool _looksLikeEmailExists(String msg) {
  return msg.contains('already') ||
      msg.contains('exist') ||
      msg.contains('registered') ||
      msg.contains('taken');
}

/// Picks Supabase refresh JWT for [GoTrueClient.setSession]. Prefer **`refreshToken`** (API contract).
String? _parseRefreshToken(Map<String, dynamic> map) {
  String? pick(dynamic v) {
    if (v is String && v.isNotEmpty) return v;
    return null;
  }

  String? pickPair(Map<String, dynamic> m) =>
      pick(m['refreshToken']) ?? pick(m['refresh_token']);

  var rt = pickPair(map);
  if (rt != null) return rt;

  final session = map['session'];
  if (session is Map) {
    rt = pickPair(Map<String, dynamic>.from(session));
    if (rt != null) return rt;
  }

  final data = map['data'];
  if (data is Map) {
    final m = Map<String, dynamic>.from(data);
    rt = pickPair(m);
    if (rt != null) return rt;
    final inner = m['session'];
    if (inner is Map) {
      rt = pickPair(Map<String, dynamic>.from(inner));
      if (rt != null) return rt;
    }
  }

  return null;
}
