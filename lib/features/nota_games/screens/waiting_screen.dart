import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainware/features/nota_games/managers/session_manager.dart';
import 'package:trainware/features/nota_games/models/session_status.dart';
import 'package:trainware/features/nota_games/widgets/leave_session_button.dart';
import 'package:trainware/features/nota_games/widgets/nota_screen_scaffold.dart';

class WaitingScreen extends StatelessWidget {
  const WaitingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.watch<SessionManager>().session;
    final status = context.watch<SessionManager>().status;

    final subtitle = switch (status) {
      SessionStatus.paused => 'Session paused',
      SessionStatus.passBreak => 'Pass break — get ready',
      _ => 'Waiting for the host to start…',
    };

    return NotaScreenScaffold(
      appBar: notaAppBar(
        title: 'NOTA Games',
        actions: const [LeaveSessionButton()],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: 32),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          if (session != null) ...[
            const SizedBox(height: 12),
            Text(
              session.playerName,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              session.sessionId,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
