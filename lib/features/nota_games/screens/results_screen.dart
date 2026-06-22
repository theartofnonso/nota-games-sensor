import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainware/features/nota_games/core/player_identity_store.dart';
import 'package:trainware/features/nota_games/managers/session_manager.dart';
import 'package:trainware/features/nota_games/services/leaderboard_service.dart';
import 'package:trainware/features/nota_games/widgets/nota_screen_scaffold.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final session = context.watch<SessionManager>().session;
    final entries = context.watch<LeaderboardService>().entries;

    return NotaScreenScaffold(
      padding: const EdgeInsets.all(24),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Session complete',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (session != null) ...[
            const SizedBox(height: 8),
            Text(
              PlayerIdentityStore.displayName(session.playerName),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
          ],
          const SizedBox(height: 32),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      'Final scores will appear here.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: entries.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      return Text(
                        '#${entry.rank}  '
                        '${PlayerIdentityStore.displayName(entry.playerName)}  '
                        '${entry.totalXp.toStringAsFixed(0)}',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight:
                              index == 0 ? FontWeight.w800 : FontWeight.w500,
                        ),
                      );
                    },
                  ),
          ),
          OpacityButtonWidgetTwo(
            onPressed: () {
              context.read<SessionManager>().resetAfterResults();
            },
            label: 'Done',
            showArrowRight: false,
            buttonColor: theme.colors.vibrantAccent,
          ),
        ],
      ),
    );
  }
}
