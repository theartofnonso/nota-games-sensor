import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import '../../app_flavor.dart';
import '../../controllers/access_controller.dart';
import '../../screens/chat/coach_ai_chat_screen.dart';

/// Coach-only AI chat entry point with the same FAB treatment used by chat.
class CoachAiChatFab extends StatelessWidget {
  const CoachAiChatFab({super.key});

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isCoach) return const SizedBox.shrink();
    final access = context.watch<ClientOverrideController>();
    if (!access.hasSelectedClient) return const SizedBox.shrink();

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.amber.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => showCoachAiChatBottomSheet(context: context),
              borderRadius: BorderRadius.circular(28),
              child: const Center(
                child: FaIcon(
                  FontAwesomeIcons.wandMagicSparkles,
                  color: Colors.amber,
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
