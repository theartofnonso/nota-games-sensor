/// Public SDK keys from the RevenueCat dashboard (Project settings → API keys).
///
/// **Test Store:** A single `test_...` key works for local / Test Store builds.
/// **Production:** Prefer platform keys via `--dart-define`:
/// `REVENUECAT_APPLE_API_KEY=appl_...`, `REVENUECAT_GOOGLE_API_KEY=goog_...`.
///
/// `REVENUECAT_API_KEY` overrides the default test key when set.
class RevenueCatConfig {
  /// Unified key (Test Store or single-app key from RevenueCat).
  static const String publicSdkKey = String.fromEnvironment(
    'REVENUECAT_API_KEY',
    defaultValue: 'test_nRsuyuUvZhuiPMRauqjZDbbyKEB',
  );

  static const String appleApiKey = String.fromEnvironment(
    'REVENUECAT_APPLE_API_KEY',
    defaultValue: '',
  );

  static const String googleApiKey = String.fromEnvironment(
    'REVENUECAT_GOOGLE_API_KEY',
    defaultValue: '',
  );
}
