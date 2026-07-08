import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gameware/features/nota_games/managers/session_manager.dart';
import 'package:gameware/features/nota_games/services/motion_service.dart';
import 'package:gameware/features/nota_games/widgets/leave_session_button.dart';
import 'package:gameware/features/nota_games/widgets/nota_screen_scaffold.dart';
import 'package:gameware/features/nota_games/widgets/session_activity_panel.dart';
import 'package:gameware/utils/theme/color_extensions.dart';

class WorkoutScreen extends StatefulWidget {
  const WorkoutScreen({super.key});

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen>
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
    final theme = Theme.of(context);
    final accent = theme.colors.vibrantAccent;
    final sessionManager = context.watch<SessionManager>();
    final motion = context.watch<MotionService>();
    final session = sessionManager.session;
    final sensorActive = sessionManager.gameState.sensorActive;

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
          pulseController: _pulseController,
          accentColor: sensorActive ? accent : null,
          pulseColor: session?.pulseColor,
          dimmed: !sensorActive,
          sensorError: motion.sensorError,
        ),
      ),
    );
  }
}
