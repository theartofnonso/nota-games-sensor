import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainware/features/nota_games/managers/session_manager.dart';
import 'package:trainware/utils/dialog_utils.dart';

/// App bar action — confirms then calls [SessionManager.leaveSession].
class LeaveSessionButton extends StatelessWidget {
  const LeaveSessionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Leave session',
      icon: const Icon(Icons.logout_rounded),
      onPressed: () => _confirmLeave(context),
    );
  }

  void _confirmLeave(BuildContext context) {
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
}
