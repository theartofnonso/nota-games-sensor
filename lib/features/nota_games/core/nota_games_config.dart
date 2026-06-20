/// NOTA Games client configuration.
///
/// Maps to backend handoff env vars:
/// - [serverUrl] → `SERVER_URL`
/// - Supabase URL/key → [SupabaseConfig] (`SUPABASE_URL`, `SUPABASE_ANON_KEY`)
abstract final class NotaGamesConfig {
  /// Game engine REST base URL (`SERVER_URL`). Empty = stub HTTP (debug log only).
  static const String serverUrl = '';

  /// When true, [RealtimeService] emits local events instead of Supabase channels.
  static const bool useStubRealtime = true;

  /// Stub only: auto-transition to [SessionStatus.active] shortly after join.
  static const bool stubAutoActivateOnJoin = true;

  static const Duration stubActivateDelay = Duration(seconds: 2);

  /// Device sample interval — 50 ms → 20 Hz per schema.
  static const Duration motionSampleInterval = Duration(milliseconds: 50);

  static const double motionSampleRateHz = 20;

  /// How often raw samples are batched and posted (`POST /sessions/:id/motion`).
  static const Duration motionBatchInterval = Duration(seconds: 5);
}
