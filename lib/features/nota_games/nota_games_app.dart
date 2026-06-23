import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:trainware/features/nota_games/core/api_client.dart';
import 'package:trainware/features/nota_games/core/nota_games_bootstrap.dart';
import 'package:trainware/features/nota_games/managers/session_manager.dart';
import 'package:trainware/features/nota_games/nota_games_shell.dart';
import 'package:trainware/features/nota_games/services/motion_service.dart';
import 'package:trainware/features/nota_games/services/realtime_service.dart';
import 'package:trainware/features/nota_games/services/session_service.dart';
import 'package:trainware/utils/theme/system_ui_overlay.dart';
import 'package:trainware/utils/theme/theme.dart';

/// NOTA Games player shell — event-driven session flow.
class NotaGamesApp extends StatefulWidget {
  const NotaGamesApp({super.key});

  @override
  State<NotaGamesApp> createState() => _NotaGamesAppState();
}

class _NotaGamesAppState extends State<NotaGamesApp> {
  late final Future<void> _bootstrap = NotaGamesBootstrap.run();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _bootstrap,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: TRKRTheme.darkTheme,
            home: const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        return MultiProvider(
          providers: [
            Provider(create: (_) => NotaApiClient()),
            Provider(create: (c) => SessionService(apiClient: c.read())),
            Provider(create: (_) => RealtimeService()),
            ChangeNotifierProvider(
              create: (c) => MotionService(sessionService: c.read()),
            ),
            ChangeNotifierProvider(
              create: (c) => SessionManager(
                sessionService: c.read<SessionService>(),
                realtimeService: c.read<RealtimeService>(),
                motionService: c.read<MotionService>(),
              ),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            themeMode: ThemeMode.dark,
            theme: TRKRTheme.darkTheme,
            darkTheme: TRKRTheme.darkTheme,
            home: const NotaGamesShell(),
            builder: (context, child) {
              SystemChrome.setSystemUIOverlayStyle(trkrDarkSystemUiOverlay);
              return child ?? const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }
}
