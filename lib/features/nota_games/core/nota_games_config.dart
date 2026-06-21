import 'nota_server_config.dart';

/// NOTA Games client configuration.
///
/// - [serverUrl] → [NotaServerConfig.serverUrl] (production game engine)
/// - Supabase URL/key → [SupabaseConfig] (Realtime channels)
abstract final class NotaGamesConfig {
  /// Game engine REST base URL (`SERVER_URL`).
  static const String serverUrl = NotaServerConfig.serverUrl;

  /// Device sample interval — 50 ms → 20 Hz per schema.
  static const Duration motionSampleInterval = Duration(milliseconds: 50);

  static const double motionSampleRateHz = 20;

  /// How often raw samples are batched and posted (`POST /sessions/:id/motion`).
  static const Duration motionBatchInterval = Duration(seconds: 5);
}
