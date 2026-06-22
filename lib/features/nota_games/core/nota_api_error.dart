import 'dart:convert';

/// Parses the handoff error envelope (`error`, optional `issues`).
String? parseNotaApiErrorMessage(String body) {
  try {
    final json = jsonDecode(body);
    if (json is! Map) return null;

    final issues = json['issues'];
    if (issues is List && issues.isNotEmpty) {
      final parts = <String>[];
      for (final issue in issues) {
        if (issue is! Map) continue;
        final path = issue['path'];
        final message = issue['message'];
        if (path != null && message != null) {
          parts.add('$path: $message');
        } else if (message != null) {
          parts.add(message.toString());
        }
      }
      if (parts.isNotEmpty) return parts.join('\n');
    }

    final error = json['error'];
    if (error is String && error.isNotEmpty) return error;
  } catch (_) {
    // Non-JSON error bodies fall through.
  }
  return null;
}
