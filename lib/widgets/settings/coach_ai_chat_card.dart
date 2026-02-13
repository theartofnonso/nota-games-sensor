import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/access_controller.dart';
import '../../utils/theme/color_extensions.dart';
import '../../screens/chat/coach_ai_chat_screen.dart';

/// Coach only: minimal entry point for AI chat. Text-input style — tap to open chat.
/// Shown when a client is selected.
class CoachAiChatCard extends StatelessWidget {
  const CoachAiChatCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ClientOverrideController>(
      builder: (context, controller, _) {
        final hasClient = controller.hasSelectedClient;
        final clientName =
            controller.selectedClientName?.trim().isNotEmpty == true
                ? controller.selectedClientName!.trim()
                : 'this client';

        if (!hasClient) return const SizedBox.shrink();

        final theme = Theme.of(context);
        final colors = theme.colors;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _openAiChat(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.black12.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      size: 18,
                      color: colors.vibrantAccent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Ask about $clientName...',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openAiChat(BuildContext context) {
    showCoachAiChatBottomSheet(context: context);
  }
}
