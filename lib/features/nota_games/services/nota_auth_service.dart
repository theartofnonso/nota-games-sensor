import 'package:supabase_flutter/supabase_flutter.dart';

/// Supabase Auth for NOTA API calls (`Authorization: Bearer <jwt>`).
///
/// Uses anonymous sign-in when there is no session so players can join without
/// email/password. The instructor must register this device's [playerId] on the
/// dashboard before join succeeds.
class NotaAuthService {
  /// Ensures a Supabase session exists; signs in anonymously if needed.
  Future<void> ensureSession() async {
    final client = Supabase.instance.client;
    if (client.auth.currentSession != null) return;
    await client.auth.signInAnonymously();
  }

  Future<String?> getAccessToken() async {
    return Supabase.instance.client.auth.currentSession?.accessToken;
  }
}
