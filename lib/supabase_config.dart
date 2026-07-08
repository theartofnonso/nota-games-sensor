import 'package:gameware/features/nota_games/core/app_env.dart';

/// Supabase Realtime credentials (`SUPABASE_URL`, `SUPABASE_ANON_KEY`).
abstract final class SupabaseConfig {
  static const String supabaseUrl = AppEnv.supabaseUrl;
  static const String supabaseAnonKey = AppEnv.supabaseAnonKey;
}
