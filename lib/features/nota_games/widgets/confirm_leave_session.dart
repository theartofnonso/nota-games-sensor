import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainware/features/nota_games/managers/session_manager.dart';
import 'package:trainware/utils/dialog_utils.dart';

/// Confirms before leaving an active NOTA session.
void showLeaveSessionPrompt(BuildContext context) {
  showBottomSheetWithSingleAction(
    context: context,
    title: 'Leave session?',
    description:
        'You will stop sending motion data and return to the join screen.',
    actionLabel: 'Leave',
    isDestructive: true,
    action: () {
      Navigator.of(context).pop();
      context.read<SessionManager>().leaveSession();
    },
  );
}

/// Blocks accidental back navigation while a session is active.
class NotaSessionPopGuard extends StatelessWidget {
  const NotaSessionPopGuard({
    super.key,
    required this.child,
    required this.guardActive,
  });

  final Widget child;
  final bool guardActive;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !guardActive,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || !guardActive) return;
        showLeaveSessionPrompt(context);
      },
      child: child,
    );
  }
}
