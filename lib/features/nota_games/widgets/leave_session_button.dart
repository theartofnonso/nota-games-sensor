import 'package:flutter/material.dart';
import 'package:trainware/features/nota_games/widgets/confirm_leave_session.dart';

/// App bar action — confirms then calls [SessionManager.leaveSession].
class LeaveSessionButton extends StatelessWidget {
  const LeaveSessionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Leave session',
      icon: const Icon(Icons.logout_rounded),
      onPressed: () => showLeaveSessionPrompt(context),
    );
  }
}
