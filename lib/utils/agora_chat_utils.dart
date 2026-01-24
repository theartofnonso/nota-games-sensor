String toAgoraUsername(String userId) {
  final sanitized = userId.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '_');
  if (RegExp(r'^[A-Za-z]').hasMatch(sanitized)) {
    return sanitized;
  }
  return 'u_$sanitized';
}
