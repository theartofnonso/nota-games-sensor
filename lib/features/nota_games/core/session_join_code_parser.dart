/// Extracts a NOTA session id from QR / deep-link payloads shown on the controller.
abstract final class SessionJoinCodeParser {
  static final _uuidRegex = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Returns a session UUID when [raw] is recognised, otherwise null.
  static String? parse(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    if (_uuidRegex.hasMatch(trimmed)) {
      return trimmed.toLowerCase();
    }

    final uri = Uri.tryParse(trimmed);
    if (uri != null) {
      final fromQuery = uri.queryParameters['session'] ??
          uri.queryParameters['sessionId'] ??
          uri.queryParameters['code'];
      if (fromQuery != null && _uuidRegex.hasMatch(fromQuery)) {
        return fromQuery.toLowerCase();
      }

      for (final segment in uri.pathSegments.reversed) {
        if (_uuidRegex.hasMatch(segment)) {
          return segment.toLowerCase();
        }
      }
    }

    // Last path segment or token after join/
    final joinMatch = RegExp(
      r'join[/:]([0-9a-fA-F-]{36})',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (joinMatch != null) {
      final id = joinMatch.group(1)!;
      if (_uuidRegex.hasMatch(id)) return id.toLowerCase();
    }

    return null;
  }
}
