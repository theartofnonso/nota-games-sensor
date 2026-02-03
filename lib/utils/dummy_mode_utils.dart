/// Demo account emails for App Store review and demos.
/// User enters only the email; password is used behind the scenes for auto-login.
const String coachDemoEmail = 'coach@ware.health';
const String clientDemoEmail = 'client@ware.health';
const String _demoPassword = 'demo123456';

/// Checks if an email is a demo account email
bool isTestAccountEmail(String email) {
  final lower = email.toLowerCase().trim();
  return lower == coachDemoEmail.toLowerCase() ||
      lower == clientDemoEmail.toLowerCase();
}

/// Returns the password for a demo account (used internally for auto-login).
/// Returns null if not a demo account.
String? getDemoPassword(String email) {
  if (!isTestAccountEmail(email)) return null;
  return _demoPassword;
}
