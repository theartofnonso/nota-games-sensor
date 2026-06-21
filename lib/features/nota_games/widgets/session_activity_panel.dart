import 'package:flutter/material.dart';
import 'package:trainware/colors.dart';
import 'package:trainware/features/nota_games/models/player_session.dart';
import 'package:trainware/features/nota_games/widgets/running_indicator.dart';

/// Shared in-session layout — centered motion indicator, player name at bottom.
class SessionActivityPanel extends StatelessWidget {
  const SessionActivityPanel({
    super.key,
    this.session,
    required this.motionActive,
    this.dimmed = false,
    this.pulseController,
    this.accentColor,
    this.phaseLabel,
    this.sensorError,
  });

  final PlayerSession? session;
  final bool motionActive;
  final bool dimmed;
  final AnimationController? pulseController;
  final Color? accentColor;
  final String? phaseLabel;
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
                  if (phaseLabel != null) ...[
                    Text(
                      phaseLabel!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.65,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
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
                session!.playerName,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontFamily: 'Foun',
                  fontWeight: FontWeight.w700,
                  color: dimmed
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
    if (motionActive && pulseController != null && !dimmed) {
      return RunningIndicator(
        controller: pulseController!,
        color: accentColor!,
      );
    }
    if (dimmed && pulseController != null) {
      return RunningIndicator(
        controller: pulseController!,
        color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
        dimmed: true,
      );
    }
    return Icon(
      Icons.sensors_off_outlined,
      size: 72,
      color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
    );
  }
}
