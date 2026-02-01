import 'package:supabase_flutter/supabase_flutter.dart';

/// Returns headers for *.notathletes.com API calls, including Bearer token.
Map<String, String> notathletesAuthHeaders() {
  final token = Supabase.instance.client.auth.currentSession?.accessToken;
  return {
    'Content-Type': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };
}
