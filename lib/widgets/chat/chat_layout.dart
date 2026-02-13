import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Shared chat UI layout used by both coach-client chat and coach-AI chat.
/// Same header structure, empty state, and input area.
/// Strip [showAttachmentButton] and [headerActions] as needed per use case.
class ChatLayout extends StatelessWidget {
  final Widget headerLeading;
  final String title;
  final List<Widget> headerActions;
  final Widget messagesContent;
  final TextEditingController messageController;
  final VoidCallback onSend;
  final bool isSending;
  final bool showAttachmentButton;
  final VoidCallback? onAttachmentTap;
  final String inputHint;

  const ChatLayout({
    super.key,
    required this.headerLeading,
    required this.title,
    required this.headerActions,
    required this.messagesContent,
    required this.messageController,
    required this.onSend,
    required this.isSending,
    this.showAttachmentButton = false,
    this.onAttachmentTap,
    this.inputHint = 'Type a message...',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Row(
            children: [
              headerLeading,
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isDarkMode ? Colors.white : Colors.black,
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
              ...headerActions,
            ],
          ),
        ),
        // Messages
        Expanded(child: messagesContent),
        // Input
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            16 + MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SafeArea(
            top: false,
            child: GestureDetector(
              onVerticalDragUpdate: (details) {
                if (details.delta.dy > 6) {
                  FocusScope.of(context).unfocus();
                }
              },
              child: _ChatInputArea(
                controller: messageController,
                onSend: onSend,
                isSending: isSending,
                isDarkMode: isDarkMode,
                showAttachmentButton: showAttachmentButton,
                onAttachmentTap: onAttachmentTap,
                hintText: inputHint,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Shared empty state for chat - same look as coach-client chat.
class ChatEmptyState extends StatelessWidget {
  final String title;
  final String subtitle;

  const ChatEmptyState({
    super.key,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : Colors.black87;
    final descriptionColor =
        isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black54;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              FaIcon(
                FontAwesomeIcons.message,
                size: 48,
                color: descriptionColor,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: descriptionColor,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shared input area - matches coach-client chat. Optional left attachment button.
class _ChatInputArea extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isSending;
  final bool isDarkMode;
  final bool showAttachmentButton;
  final VoidCallback? onAttachmentTap;
  final String hintText;

  const _ChatInputArea({
    required this.controller,
    required this.onSend,
    required this.isSending,
    required this.isDarkMode,
    required this.showAttachmentButton,
    this.onAttachmentTap,
    required this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leftPadding = showAttachmentButton ? 52.0 : 20.0;

    return Container(
      padding: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: isDarkMode
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.2)
              : Colors.black.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Stack(
        children: [
          TextField(
            controller: controller,
            enabled: !isSending,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDarkMode ? Colors.white : Colors.black,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: Colors.grey.withValues(alpha: 0.5),
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              contentPadding: EdgeInsets.fromLTRB(
                leftPadding,
                12,
                52,
                12,
              ),
            ),
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            onSubmitted: (_) => onSend(),
          ),
          if (showAttachmentButton && onAttachmentTap != null)
            Positioned(
              left: 8,
              bottom: 8,
              child: _ChatInputIconButton(
                icon: Icons.add,
                isDarkMode: isDarkMode,
                onTap: onAttachmentTap,
              ),
            ),
          Positioned(
            right: 8,
            bottom: 8,
            child: _ChatInputIconButton(
              icon: FontAwesomeIcons.arrowUp,
              isDarkMode: isDarkMode,
              onTap: isSending ? null : onSend,
              isLoading: isSending,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatInputIconButton extends StatelessWidget {
  final IconData icon;
  final bool isDarkMode;
  final VoidCallback? onTap;
  final bool isLoading;

  const _ChatInputIconButton({
    required this.icon,
    required this.isDarkMode,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final background = isDarkMode
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.08);
    return SizedBox(
      width: 36,
      height: 36,
      child: Material(
        color: background,
        shape: const CircleBorder(),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Icon(
                    icon,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: 16,
                  ),
          ),
        ),
      ),
    );
  }
}

/// Shared message bubble - same visual style as coach-client chat.
/// Use [isMarkdown] for AI responses to render Markdown.
class ChatTextBubble extends StatelessWidget {
  final bool isCurrentUser;
  final String text;
  final String timestamp;
  final bool isMarkdown;

  const ChatTextBubble({
    super.key,
    required this.isCurrentUser,
    required this.text,
    required this.timestamp,
    this.isMarkdown = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final outgoingColor = Colors.white;
    final incomingColor = Colors.black;
    final bubbleColor = isCurrentUser ? outgoingColor : incomingColor;
    final textColor = isCurrentUser ? Colors.black : Colors.white;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Flexible(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxBubbleWidth = constraints.maxWidth * 0.75;
                return ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: 100,
                    maxWidth: maxBubbleWidth,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft: Radius.circular(isCurrentUser ? 18 : 4),
                        bottomRight: Radius.circular(isCurrentUser ? 4 : 18),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        isMarkdown
                            ? MarkdownBody(
                                data: text,
                                selectable: true,
                                styleSheet: MarkdownStyleSheet(
                                  p: theme.textTheme.bodyMedium?.copyWith(
                                    color: textColor,
                                    height: 1.5,
                                  ),
                                  strong: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                  listBullet: theme.textTheme.bodyMedium
                                      ?.copyWith(color: textColor),
                                  h1: theme.textTheme.titleLarge
                                      ?.copyWith(color: textColor),
                                  h2: theme.textTheme.titleMedium
                                      ?.copyWith(color: textColor),
                                  h3: theme.textTheme.titleSmall
                                      ?.copyWith(color: textColor),
                                  code: theme.textTheme.bodyMedium?.copyWith(
                                    backgroundColor: textColor.withValues(
                                      alpha: isCurrentUser ? 0.15 : 0.2,
                                    ),
                                    color: textColor,
                                    fontFamily: 'monospace',
                                  ),
                                  blockquote: theme.textTheme.bodyMedium
                                      ?.copyWith(
                                        color: textColor,
                                        fontStyle: FontStyle.italic,
                                      ),
                                ),
                              )
                            : Text(
                                text,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: textColor,
                                  fontWeight: FontWeight.w400,
                                  fontSize: 16,
                                ),
                              ),
                        const SizedBox(height: 4),
                        Text(
                          timestamp,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: textColor.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
