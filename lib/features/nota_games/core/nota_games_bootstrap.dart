import 'package:trainware/shared_prefs.dart';
import 'package:trainware/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'nota_games_config.dart';
import '../services/nota_auth_service.dart';

/// One-time setup for the NOTA player shell.
abstract final class NotaGamesBootstrap {
  static Future<void> run() async {
    await SharedPrefs().init();

    if (!_needsSupabase) return;

    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );
    await NotaAuthService().ensureSession();
  }

  static bool get _needsSupabase =>
      NotaGamesConfig.serverUrl.isNotEmpty || !NotaGamesConfig.useStubRealtime;
}
