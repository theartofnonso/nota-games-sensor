/// Test account email for App Store review and demos
const String testAccountEmail = 'test@ware.health';

/// Checks if an email is the test account email
bool isTestAccountEmail(String email) {
  return email.toLowerCase() == testAccountEmail.toLowerCase();
}
