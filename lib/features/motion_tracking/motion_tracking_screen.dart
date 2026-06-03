import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainware/colors.dart';
import 'package:trainware/features/motion_tracking/motion_tracking_controller.dart';
import 'package:trainware/utils/dialog_utils.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';

/// NOTA Games phone motion test — accelerometer → player id → live metrics.
class MotionTrackingScreen extends StatefulWidget {
  const MotionTrackingScreen({super.key});

  @override
  State<MotionTrackingScreen> createState() => _MotionTrackingScreenState();
}

class _MotionTrackingScreenState extends State<MotionTrackingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MotionTrackingController>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<MotionTrackingController>();
    final theme = Theme.of(context);
    final showValues = c.status != MotionTrackingStatus.idle;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(gradient: themeGradient(context: context)),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppBar(
                title: const Text('NOTA Games Motion Controller'),
                centerTitle: true,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Player ${c.playerId}',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.4,
                          ),
                          letterSpacing: 0.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (c.sensorError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          c.sensorError!,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: error,
                          ),
                        ),
                      ],
                      Expanded(
                        child: Column(
                          children: [
                            const Spacer(flex: 2),
                            _CenterMetric(
                              label: 'Session score',
                              value:
                                  showValues
                                      ? c.sessionScore.toStringAsFixed(1)
                                      : '—',
                            ),
                            const Spacer(flex: 3),
                            _CenterMetric(
                              label: 'Smoothed',
                              value:
                                  showValues
                                      ? c.smoothedMagnitude.toStringAsFixed(2)
                                      : '—',
                            ),
                            const Spacer(flex: 2),
                          ],
                        ),
                      ),
                      _MotionTrackingActions(
                        isTracking: c.isTracking,
                        onStartStop: () {
                          if (c.isTracking) {
                            _confirmStopTracking(context, c);
                          } else {
                            c.startTracking();
                          }
                        },
                        onReset: () => _confirmReset(context, c),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmStopTracking(
    BuildContext context,
    MotionTrackingController controller,
  ) {
    showBottomSheetWithSingleAction(
      context: context,
      title: 'Stop tracking?',
      description:
          'End this session. Your score and smoothed reading stay on screen until you reset.',
      actionLabel: 'Stop Tracking',
      isDestructive: true,
      action: () {
        Navigator.of(context).pop();
        controller.stopTracking();
      },
    );
  }

  void _confirmReset(
    BuildContext context,
    MotionTrackingController controller,
  ) {
    showBottomSheetWithSingleAction(
      context: context,
      title: 'Reset session?',
      description:
          controller.isTracking
              ? 'Stop tracking and clear your score and motion readings.'
              : 'Clear your score and motion readings and return to a clean state.',
      actionLabel: 'Reset',
      actionColor: Colors.white,
      action: () {
        Navigator.of(context).pop();
        controller.resetSession();
      },
    );
  }
}

/// Bottom actions — same [OpacityButtonWidgetTwo] pattern as shell / settings.
class _MotionTrackingActions extends StatelessWidget {
  const _MotionTrackingActions({
    required this.isTracking,
    required this.onStartStop,
    required this.onReset,
  });

  final bool isTracking;
  final VoidCallback onStartStop;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colors;
    final startStopColor = isTracking ? error : colors.vibrantAccent;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SizedBox(
            width: double.infinity,
            child: OpacityButtonWidgetTwo(
              onPressed: onStartStop,
              label: isTracking ? 'Stop Tracking' : 'Start Tracking',
              showArrowRight: false,
              buttonColor: startStopColor,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            width: double.infinity,
            child: OpacityButtonWidgetTwo(
              onPressed: onReset,
              label: 'Reset',
              showArrowRight: false,
              buttonColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

class _CenterMetric extends StatelessWidget {
  const _CenterMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: onSurface.withValues(alpha: 0.55),
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 12),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            textAlign: TextAlign.center,
            style: theme.textTheme.displayLarge?.copyWith(
              fontSize: 80,
              fontWeight: FontWeight.w900,
              height: 0.95,
              letterSpacing: -2,
              color: onSurface,
            ),
          ),
        ),
      ],
    );
  }
}
