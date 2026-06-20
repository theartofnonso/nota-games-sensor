import 'dart:convert';

import 'package:http/http.dart' as http;

import 'nota_games_config.dart';
import '../services/nota_auth_service.dart';

/// HTTP client for the NOTA game engine (`SERVER_URL`).
///
/// All requests include `Authorization: Bearer <supabase_access_token>` per
/// backend handoff. Call [NotaGamesBootstrap.run] before first request.
class NotaApiClient {
  NotaApiClient({NotaAuthService? authService})
      : _authService = authService ?? NotaAuthService();

  final NotaAuthService _authService;

  Uri _uri(String path) {
    final base = NotaGamesConfig.serverUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    final token = await _authService.getAccessToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<http.Response> post(
    String path, {
    Map<String, dynamic> body = const {},
  }) async {
    if (NotaGamesConfig.serverUrl.isEmpty) {
      throw const NotaApiStubException();
    }
    return http.post(
      _uri(path),
      headers: await _headers(),
      body: jsonEncode(body),
    );
  }

  Future<http.Response> delete(String path) async {
    if (NotaGamesConfig.serverUrl.isEmpty) {
      throw const NotaApiStubException();
    }
    return http.delete(_uri(path), headers: await _headers());
  }
}

/// Thrown when [NotaGamesConfig.serverUrl] is empty (local stub mode).
class NotaApiStubException implements Exception {
  const NotaApiStubException();
}

class SessionUnauthorizedException implements Exception {
  const SessionUnauthorizedException();
}
