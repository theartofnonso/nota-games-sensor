import 'package:flutter/material.dart';
import 'package:trainware/app_keys.dart';

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
/// Uses [rootNavigatorKey] when [context] is unmounted (e.g. user navigated
/// away during the async operation) so the overlay is always dismissed.
///
/// Uses [Navigator.canPop] so we never pop GoRouter's last page (e.g. when the
/// overlay was already removed by [context.pop] or dispose order is wrong).
void hideCoachLoadingOverlay(BuildContext context) {
  final ctx = context.mounted ? context : rootNavigatorKey.currentContext;
  if (ctx == null) return;
  final nav = Navigator.of(ctx, rootNavigator: true);
  if (nav.canPop()) {
    nav.pop();
  }
}
