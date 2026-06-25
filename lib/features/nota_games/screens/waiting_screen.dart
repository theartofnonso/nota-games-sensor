import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gameware/features/nota_games/managers/session_manager.dart';
import 'package:gameware/features/nota_games/widgets/leave_session_button.dart';
import 'package:gameware/features/nota_games/widgets/nota_screen_scaffold.dart';
import 'package:gameware/features/nota_games/widgets/session_activity_panel.dart';

class WaitingScreen extends StatefulWidget {
  const WaitingScreen({super.key});

  @override
  State<WaitingScreen> createState() => _WaitingScreenState();
}

class _WaitingScreenState extends State<WaitingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionManager>().session;

    return NotaScreenScaffold(
      appBar: notaAppBar(
        context: context,
        title: 'Nota Games Sensor',
        actions: const [LeaveSessionButton()],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: SessionActivityPanel(
          session: session,
          dimmed: true,
          pulseController: _pulseController,
        ),
      ),
    );
  }
}
