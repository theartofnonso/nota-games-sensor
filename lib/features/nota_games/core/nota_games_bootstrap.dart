import 'package:flutter/foundation.dart';
import 'package:trainware/shared_prefs.dart';
import 'package:trainware/supabase_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'api_client.dart';

/// One-time setup for the NOTA player shell.
abstract final class NotaGamesBootstrap {
  static Future<void> run() async {
    await SharedPrefs().init();

    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
    );

    final healthy = await NotaApiClient().checkHealth();
    if (!healthy && kDebugMode) {
      debugPrint(
        'NOTA: game engine health check failed — verify nota_server_config.dart',
      );
    }
  }
}
