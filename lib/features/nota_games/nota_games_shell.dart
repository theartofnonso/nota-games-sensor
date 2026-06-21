import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainware/features/nota_games/managers/session_manager.dart';
import 'package:trainware/features/nota_games/screens/join_session_screen.dart';
import 'package:trainware/features/nota_games/screens/results_screen.dart';
import 'package:trainware/features/nota_games/screens/waiting_screen.dart';
import 'package:trainware/features/nota_games/screens/workout_screen.dart';

/// Routes UI from [SessionManager] state — screens never start/stop motion.
class NotaGamesShell extends StatelessWidget {
  const NotaGamesShell({super.key});

  @override
  Widget build(BuildContext context) {
    final manager = context.watch<SessionManager>();
    final state = manager.runtimeState;

    if (!manager.hasSession) {
      return const JoinSessionScreen();
    }

    if (state.isSessionComplete) {
      return const ResultsScreen();
    }
    if (state.isInSession) {
      return const WorkoutScreen();
    }
    return const WaitingScreen();
  }
}
