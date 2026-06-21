import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainware/colors.dart';
import 'package:trainware/features/nota_games/managers/session_manager.dart';
import 'package:trainware/features/nota_games/models/leaderboard_entry.dart';
import 'package:trainware/features/nota_games/models/session_runtime_state.dart';
import 'package:trainware/features/nota_games/services/leaderboard_service.dart';
import 'package:trainware/features/nota_games/services/motion_service.dart';
import 'package:trainware/features/nota_games/widgets/leave_session_button.dart';
import 'package:trainware/features/nota_games/widgets/running_indicator.dart';
import 'package:trainware/features/nota_games/widgets/nota_screen_scaffold.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

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
    final leaderboard = context.watch<LeaderboardService>();
    final session = sessionManager.session;
    final state = sessionManager.runtimeState;
    final isCollecting = state.isMotionEligible && motion.isCollecting;
    final phaseLabel = switch (state.phase) {
      SessionPhase.work when state.isPaused => 'Paused',
      SessionPhase.work => 'Work',
      SessionPhase.rest => 'Rest',
      SessionPhase.passBreak => 'Pass break',
      _ => null,
    };

    return NotaScreenScaffold(
      appBar: notaAppBar(
        title: 'NOTA Games',
        actions: const [LeaveSessionButton()],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (leaderboard.entries.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _LeaderboardStrip(entries: leaderboard.entries),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                      if (session != null) ...[
                        Text(
                          session.playerName,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          session.playerId,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.4,
                            ),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (phaseLabel != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          phaseLabel,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.65,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 48),
                      if (isCollecting)
                        RunningIndicator(
                          controller: _pulseController,
                          color: accent,
                        )
                      else
                        Icon(
                          Icons.sensors_off_outlined,
                          size: 72,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.35,
                          ),
                        ),
                      if (motion.sensorError != null) ...[
                        const SizedBox(height: 32),
                        Text(
                          motion.sensorError!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: error,
                          ),
                        ),
                      ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LeaderboardStrip extends StatelessWidget {
  const _LeaderboardStrip({required this.entries});

  final List<LeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = entries.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Leaderboard',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
          ),
        ),
        const SizedBox(height: 8),
        ...top.map(
          (e) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '#${e.rank} ${e.playerName} — ${e.totalXp.toStringAsFixed(0)}',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
      ],
    );
  }
}
