import 'app_env.dart';

/// NOTA Games client configuration.
abstract final class NotaGamesConfig {
  /// Game engine REST base URL (`SERVER_URL`).
  static const String serverUrl = AppEnv.serverUrl;

  /// Device sample interval — 50 ms → 20 Hz per handoff.
  static const Duration motionSampleInterval = Duration(milliseconds: 50);

  static const double motionSampleRateHz = 20;

  /// Motion batch upload interval — every 5 seconds while `sensorActive`.
  static const Duration motionBatchInterval = Duration(seconds: 5);
}
