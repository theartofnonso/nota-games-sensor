/// Placeholders for **unlisted** (internal) coach/client app builds: no IAP, no
/// subscription gate. Coaches pick a client from the clients list like retail.
class UnlistedDistributionConfig {
  UnlistedDistributionConfig._();

  /// Default coach (`auth.users.id`) for unlisted **client** builds, passed to
  /// **`POST /unlisted-client-bootstrap`** which ensures `clients` + `coach_clients`.
  /// Retail ignores this.
  static const String placeholderCoachUserId =
      'f92a43e1-97e4-4048-884c-4c8eb9571546';
}
