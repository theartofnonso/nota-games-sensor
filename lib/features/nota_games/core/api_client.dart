import 'dart:convert';

import 'package:http/http.dart' as http;

import 'nota_games_config.dart';

/// HTTP client for the NOTA game engine ([NotaGamesConfig.serverUrl]).
///
/// Player routes require no authentication. Call [NotaGamesBootstrap.run]
/// before first request.
class NotaApiClient {
  NotaApiClient();

  Uri _uri(String path) {
    final base = NotaGamesConfig.serverUrl.replaceAll(RegExp(r'/+$'), '');
    return Uri.parse('$base$path');
  }

  Map<String, String> get _headers => const {
        'Content-Type': 'application/json',
      };

  Future<http.Response> post(
    String path, {
    Map<String, dynamic> body = const {},
  }) async {
    return http.post(
      _uri(path),
      headers: _headers,
      body: jsonEncode(body),
    );
  }

  Future<http.Response> delete(
    String path, {
    Map<String, dynamic> body = const {},
  }) async {
    final request = http.Request('DELETE', _uri(path))
      ..headers.addAll(_headers)
      ..body = jsonEncode(body);
    final streamed = await request.send();
    return http.Response.fromStream(streamed);
  }

  /// `GET /health` — confirms the game engine is reachable.
  Future<bool> checkHealth() async {
    final response = await http.get(_uri('/health'), headers: _headers);
    if (response.statusCode != 200) return false;
    final json = jsonDecode(response.body);
    return json is Map && json['ok'] == true;
  }
}
