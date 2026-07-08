/// Runtime configuration — supply via `--dart-define` (do not commit secrets).
///
/// | Variable            | Used by |
/// |---------------------|---------|
/// | `SERVER_URL`        | REST API |
/// | `SUPABASE_URL`      | Realtime |
/// | `SUPABASE_ANON_KEY` | Realtime |
abstract final class AppEnv {
  static const String serverUrl = String.fromEnvironment(
    'SERVER_URL',
    defaultValue:
        'https://nota-game-engine-production.up.railway.app',
  );

  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://psblxphtjqyymlexuydi.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_NMZlMh-S8c1rfIaREy4evQ_48QlPsxR',
  );
}
