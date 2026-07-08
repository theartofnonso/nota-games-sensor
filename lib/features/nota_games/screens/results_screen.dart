import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gameware/features/nota_games/core/player_identity_store.dart';
import 'package:gameware/features/nota_games/managers/session_manager.dart';
import 'package:gameware/features/nota_games/models/team.dart';
import 'package:gameware/features/nota_games/widgets/nota_screen_scaffold.dart';
import 'package:gameware/utils/theme/color_extensions.dart';

/// Shown after `sessionEnded` — handoff: stop sending → `/leave` → show results.
class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colors.vibrantAccent;
    final manager = context.watch<SessionManager>();
    final session = manager.session;
    final leaderboard = manager.finalLeaderboard;
    final playerEntry =
        session != null ? leaderboard?.entryForPlayer(session.playerId) : null;
    final teamScore =
        session != null ? leaderboard?.teamScoreFor(session.team?.id) : null;
    final team = session?.team;

    return NotaScreenScaffold(
      padding: const EdgeInsets.all(24),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Session complete',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Foun',
                      fontSize: 28,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                    ),
                  ),
                  if (session != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      PlayerIdentityStore.displayName(session.playerName),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                  if (team != null) ...[
                    const SizedBox(height: 24),
                    _TeamBadge(team: team),
                  ],
                  if (playerEntry != null) ...[
                    const SizedBox(height: 32),
                    _StatCard(
                      label: 'Your rank',
                      value: '#${playerEntry.rank}',
                      accent: team?.flutterColor ?? accent,
                    ),
                    const SizedBox(height: 12),
                    _StatCard(
                      label: 'Your XP',
                      value: playerEntry.totalXp.toStringAsFixed(0),
                      accent: team?.flutterColor ?? accent,
                    ),
                  ],
                  if (teamScore != null) ...[
                    const SizedBox(height: 12),
                    _StatCard(
                      label: '${teamScore.name} team XP',
                      value: teamScore.totalXp.toStringAsFixed(0),
                      accent: parseTeamColor(teamScore.color) ?? accent,
                    ),
                  ],
                  if (playerEntry == null) ...[
                    const SizedBox(height: 32),
                    Text(
                      'Great work — scores will appear on the scoreboard.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: manager.dismissResults,
                      style: FilledButton.styleFrom(
                        backgroundColor: accent.withValues(alpha: 0.2),
                        foregroundColor: accent,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(100),
                        ),
                      ),
                      child: const Text(
                        'Done',
                        style: TextStyle(
                          fontFamily: 'Foun',
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TeamBadge extends StatelessWidget {
  const _TeamBadge({required this.team});

  final Team team;

  @override
  Widget build(BuildContext context) {
    final color = team.flutterColor;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: (color ?? theme.colorScheme.surface).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(100),
        border: color != null
            ? Border.all(color: color.withValues(alpha: 0.5))
            : null,
      ),
      child: Text(
        team.name,
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium?.copyWith(
          color: color ?? theme.colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
