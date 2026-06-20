import 'dart:convert';

/// Extracts a NOTA session id from QR / deep-link payloads shown on the controller.
abstract final class SessionJoinCodeParser {
  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static final _uuidAnywhereRegex = RegExp(
    r'[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  );

  /// Returns a session UUID when [raw] is recognised, otherwise null.
  static String? parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final direct = _normalizeUuid(trimmed);
    if (direct != null) return direct;

    final fromJson = _parseJson(trimmed);
    if (fromJson != null) return fromJson;

    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      for (final key in ['session', 'sessionId', 'code']) {
        final fromQuery = uri.queryParameters[key];
        if (fromQuery != null) {
          final parsed = _normalizeUuid(fromQuery);
          if (parsed != null) return parsed;
        }
      }

      for (final segment in uri.pathSegments.reversed) {
        final parsed = _normalizeUuid(segment);
        if (parsed != null) return parsed;
      }
    }

    final joinMatch = RegExp(
      r'join[/:]([0-9a-fA-F-]{36})',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (joinMatch != null) {
      return _normalizeUuid(joinMatch.group(1)!);
    }

    return _findUuidIn(trimmed);
  }

  static String? _normalizeUuid(String value) {
    final trimmed = value.trim();
    if (_uuidRegex.hasMatch(trimmed)) return trimmed.toLowerCase();
    return null;
  }

  static String? _parseJson(String trimmed) {
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is! Map) return null;
      for (final key in ['sessionId', 'session_id', 'id', 'code']) {
        final value = decoded[key];
        if (value is String) {
          final parsed = _normalizeUuid(value) ?? _findUuidIn(value);
          if (parsed != null) return parsed;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static String? _findUuidIn(String text) {
    final match = _uuidAnywhereRegex.firstMatch(text);
    return match?.group(0)?.toLowerCase();
  }
}
