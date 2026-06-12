import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainware/colors.dart';
import 'package:trainware/features/motion_tracking/motion_tracking_controller.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

/// NOTA Games player device — continuously samples motion and posts raw batches.
class MotionTrackingScreen extends StatefulWidget {
  const MotionTrackingScreen({super.key});

  @override
  State<MotionTrackingScreen> createState() => _MotionTrackingScreenState();
}

class _MotionTrackingScreenState extends State<MotionTrackingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MotionTrackingController>().initialize();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<MotionTrackingController>();
    final theme = Theme.of(context);
    final accent = theme.colors.vibrantAccent;

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
                title: const Text('NOTA Games'),
                centerTitle: true,
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        c.playerName,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        c.playerId,
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
                      const SizedBox(height: 48),
                      if (c.isRunning) ...[
                        _RunningIndicator(
                          controller: _pulseController,
                          color: accent,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Sending motion data',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else ...[
                        Icon(
                          Icons.sensors_off_outlined,
                          size: 72,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.35,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Waiting for sensor…',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                      ],
                      if (c.sensorError != null) ...[
                        const SizedBox(height: 32),
                        Text(
                          c.sensorError!,
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
        ),
      ),
    );
  }
}

class _RunningIndicator extends StatelessWidget {
  const _RunningIndicator({
    required this.controller,
    required this.color,
  });

  final AnimationController controller;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(controller.value);
        final outerScale = 1 + t * 0.18;
        final innerOpacity = 0.45 + t * 0.55;

        return SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: outerScale,
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.12 + t * 0.1),
                  ),
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: innerOpacity),
                  boxShadow: [
                    BoxShadow(
                      color: color.withValues(alpha: 0.35 * innerOpacity),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
