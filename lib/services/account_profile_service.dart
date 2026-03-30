import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:trainware/urls.dart';
import 'package:trainware/utils/notathletes_auth_headers.dart';

/// Returns true if the client has a row in the clients table (returning user).
Future<bool> clientProfileExists(String userId) async {
  try {
    final row = await Supabase.instance.client
        .from('clients')
        .select('id')
        .eq('id', userId)
        .maybeSingle();
    return row != null;
  } catch (_) {
    return false;
  }
}

/// Calls POST /account/profile to create a client profile (typically done from the website).
/// Body: { user_id, name } — both required.
/// On existing client: backend responds with 409.
Future<bool> createAccountProfile({
  required String userId,
  required String name,
}) async {
  try {
    final uri = Uri.parse(apiNotathletesBaseUrl).resolve(accountProfilePath);
    final response = await http.post(
      uri,
      headers: notathletesAuthHeaders(),
      body: jsonEncode({
        'user_id': userId,
        'name': name.trim(),
      }),
    ).timeout(const Duration(seconds: 15));
    return (response.statusCode >= 200 && response.statusCode < 300) ||
        response.statusCode == 409; // profile already exists (race, retry)
  } catch (_) {
    return false;
  }
}

/// Calls PATCH /account/profile to update an existing client profile.
/// Body: { user_id } required, { name } optional.
/// On non-existent client: backend responds with 404.
Future<bool> updateAccountProfile({
  required String userId,
  String? name,
}) async {
  try {
    final uri = Uri.parse(apiNotathletesBaseUrl).resolve(accountProfilePath);
    final body = <String, dynamic>{'user_id': userId};
    if (name != null && name.trim().isNotEmpty) {
      body['name'] = name.trim();
    }
    if (body.length <= 1) {
      // No updatable fields
      return false;
    }
    final response = await http.patch(
      uri,
      headers: notathletesAuthHeaders(),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
    return response.statusCode >= 200 && response.statusCode < 300;
  } catch (_) {
    return false;
  }
}
