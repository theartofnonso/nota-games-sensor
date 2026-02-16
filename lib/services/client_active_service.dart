import 'dart:convert';

import 'package:http/http.dart' as http;

import '../urls.dart';

/// Result of checking whether a client can sign in.
class ClientActiveCheckResult {
  const ClientActiveCheckResult({
    required this.exists,
    required this.isActive,
  });

  final bool exists;
  final bool isActive;

  /// Client can proceed to sign in (exists and is active).
  bool get canSignIn => exists && isActive;
}

/// Service for client active-status checks and activation.
/// Calls api.notathletes.com for both check and activate.
class ClientActiveService {
  /// Checks whether a client with the given email exists and is active.
  Future<ClientActiveCheckResult> checkActive(String email) async {
    try {
      final uri = Uri.parse(apiNotathletesBaseUrl)
          .resolve(clientCheckActivePath)
          .replace(queryParameters: {'email': email});
      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        return const ClientActiveCheckResult(exists: false, isActive: false);
      }
      final body = jsonDecode(response.body) as Map<String, dynamic>?;
      if (body == null) {
        return const ClientActiveCheckResult(exists: false, isActive: false);
      }
      final exists = body['exists'] as bool? ?? false;
      final isActive = body['is_active'] as bool? ?? false;
      return ClientActiveCheckResult(exists: exists, isActive: isActive);
    } catch (_) {
      return const ClientActiveCheckResult(exists: false, isActive: false);
    }
  }

  /// Activates a client after successful IAP. Backend validates receipt and
  /// updates clients.is_active = true.
  Future<bool> activateClient({
    required String email,
    required String receiptData,
    String platform = 'ios',
  }) async {
    try {
      final uri = Uri.parse(apiNotathletesBaseUrl).resolve(clientActivatePath);
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'receipt': receiptData,
          'platform': platform,
        }),
      ).timeout(const Duration(seconds: 30));
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (_) {
      return false;
    }
  }
}
