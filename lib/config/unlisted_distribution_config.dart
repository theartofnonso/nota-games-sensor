/// Placeholders for **unlisted** (internal) coach/client app builds: no IAP, no
/// subscription gate, coach app auto-selects a client.
///
/// Replace [preferredClientUserId] with a real Supabase `auth.users.id` when you
/// want a fixed client; leave empty to auto-select the first row from
/// [CoachClientsService] after load.
class UnlistedDistributionConfig {
  UnlistedDistributionConfig._();

  /// Optional. When non-empty, the unlisted **coach** app selects this client
  /// (must appear in `coach_clients` for the signed-in coach).
  static const String preferredClientUserId = '';

  /// Default coach (`auth.users.id`) for unlisted **client** builds, passed to
  /// **`POST /unlisted-client-bootstrap`** which ensures `clients` + `coach_clients`.
  /// Retail ignores this.
  static const String placeholderCoachUserId =
      'f92a43e1-97e4-4048-884c-4c8eb9571546';
}
