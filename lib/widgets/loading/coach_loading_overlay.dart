import 'package:flutter/material.dart';

/// Reusable loading indicator for coach operations (non–offline-first).
/// Use [CoachLoadingIndicator] inline, or [showCoachLoadingOverlay] /
/// [hideCoachLoadingOverlay] for a full-screen overlay during async work.
class CoachLoadingIndicator extends StatelessWidget {
  final double size;

  const CoachLoadingIndicator({super.key, this.size = 24});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

/// Shows a non-dismissible overlay with [CoachLoadingIndicator] during coach
/// operations. Call [hideCoachLoadingOverlay] when the operation completes.
void showCoachLoadingOverlay(BuildContext context) {
  showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    barrierLabel: 'Loading',
    useRootNavigator: true,
    transitionDuration: const Duration(milliseconds: 150),
    pageBuilder: (context, _, __) => PopScope(
      canPop: false,
      child: Material(
        type: MaterialType.transparency,
        child: Center(
          child: CoachLoadingIndicator(size: 32),
        ),
      ),
    ),
  );
}

/// Hides the coach loading overlay. Call after the coach operation completes.
/// No-op if [context] is not mounted.
void hideCoachLoadingOverlay(BuildContext context) {
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();
}
