import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../app_flavor.dart';
import '../config/unlisted_distribution_config.dart';
import '../logger.dart';
import '../shared_prefs.dart';
import '../urls.dart';
import '../utils/notathletes_auth_headers.dart';

final _log = getLogger(className: 'UnlistedClientBootstrapService');

/// Dead-simple unlisted client setup:
/// call one backend endpoint that ensures `clients` row + default coach assignment.
class UnlistedClientBootstrapService {
  UnlistedClientBootstrapService._();

  static Future<void> run() async {
    if (!AppConfig.isUnlistedClient) return;
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email?.trim();
    if (user == null || email == null || email.isEmpty) return;

    final uri =
        Uri.parse(apiNotathletesBaseUrl).resolve(unlistedClientBootstrapPath);
    final fullName = _displayName(user);
    final coachId = UnlistedDistributionConfig.placeholderCoachUserId.trim();

    try {
      final response = await http
          .post(
            uri,
            headers: notathletesAuthHeaders(),
            body: jsonEncode({
              'clientId': user.id,
              'email': email,
              'fullName': fullName,
              'coachId': coachId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      Map<String, dynamic>? map;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          map = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}

      // Idempotent success convention: 2xx success or 409 with { success: true }.
      if ((response.statusCode >= 200 && response.statusCode < 300) ||
          (response.statusCode == 409 && map?['success'] == true)) {
        SharedPrefs().profileSetupComplete = true;
        _log.i('unlisted-client-bootstrap ok (${response.statusCode})');
        return;
      }

      _log.w(
        'unlisted-client-bootstrap HTTP ${response.statusCode}: ${response.body}',
      );
    } catch (e, st) {
      _log.w('unlisted-client-bootstrap failed', error: e, stackTrace: st);
    }
  }

  static String _displayName(User user) {
    final meta = user.userMetadata;
    for (final key in ['full_name', 'name', 'display_name']) {
      final v = meta?[key];
      if (v is String && v.trim().isNotEmpty) return v.trim();
    }
    final email = user.email;
    if (email != null && email.contains('@')) {
      final local = email.split('@').first.trim();
      if (local.isNotEmpty) return local;
    }
    return 'Trainware member';
  }
}
