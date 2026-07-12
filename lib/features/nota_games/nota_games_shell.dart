import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gameware/features/nota_games/managers/session_manager.dart';
import 'package:gameware/features/nota_games/screens/join_session_screen.dart';
import 'package:gameware/features/nota_games/screens/waiting_screen.dart';
import 'package:gameware/features/nota_games/screens/workout_screen.dart';
import 'package:gameware/features/nota_games/widgets/confirm_leave_session.dart';

/// Routes UI from [SessionManager] state — screens never start/stop motion.
class NotaGamesShell extends StatelessWidget {
  const NotaGamesShell({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<SessionManager>();

    Widget screen;
    if (!manager.hasSession) {
      screen = const JoinSessionScreen();
    } else if (manager.gameState.isInSession) {
      screen = const WorkoutScreen();
    } else {
      screen = const WaitingScreen();
    }

    return NotaSessionPopGuard(
      guardActive: manager.hasSession,
      child: screen,
    );
  }
}
