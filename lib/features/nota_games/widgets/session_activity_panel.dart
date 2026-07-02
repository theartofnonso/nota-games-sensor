import 'package:flutter/material.dart';
import 'package:gameware/colors.dart';
import 'package:gameware/features/nota_games/core/player_identity_store.dart';
import 'package:gameware/features/nota_games/models/player_session.dart';
import 'package:gameware/features/nota_games/widgets/running_indicator.dart';

/// Shared in-session layout — centered motion indicator, player name at bottom.
class SessionActivityPanel extends StatelessWidget {
  const SessionActivityPanel({
    super.key,
    this.session,
    this.dimmed = false,
    this.pulseController,
    this.accentColor,
    this.pulseColor,
    this.sensorError,
  });

  final PlayerSession? session;

  /// Gray pulse while waiting for the host to start.
  final bool dimmed;
  final AnimationController? pulseController;
  final Color? accentColor;

  /// Team pulse from the controller; overrides default gray/green when set.
  final Color? pulseColor;
  final String? sensorError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox.expand(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildIndicator(theme),
                  if (sensorError != null) ...[
                    const SizedBox(height: 24),
                    Text(
                      sensorError!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: error),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (session != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                PlayerIdentityStore.displayName(session!.playerName),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'Foun',
                  fontWeight: FontWeight.w700,
                  color:
                      dimmed
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                          : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildIndicator(ThemeData theme) {
    final controller = pulseController;
    if (controller == null) return const SizedBox.shrink();

    final color = pulseColor ??
        (dimmed
            ? theme.colorScheme.onSurface.withValues(alpha: 0.35)
            : accentColor);
    if (color == null) return const SizedBox.shrink();

    return RunningIndicator(
      controller: controller,
      color: color,
      dimmed: dimmed,
    );
  }
}
