import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

import 'package:lottie/lottie.dart';

import '../../controllers/access_controller.dart';
import '../../dtos/appsync/exercise_dto.dart';
import '../../logger.dart';
import '../../utils/lottie_exercise_registry.dart';
import '../../utils/notathletes_auth_headers.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/theme/color_extensions.dart';
import '../../utils/routine_editors_utils.dart';
import '../../urls.dart';
import '../../widgets/chat/chat_layout.dart';
import '../../widgets/bottom_sheets/app_bottom_sheet.dart';

/// AI chat message: either from the coach (user) or the AI.
class _AiChatMessage {
  final bool isUser;
  final String text;
  final DateTime timestamp;
  final ExerciseDto? attachedExercise;

  _AiChatMessage({
    required this.isUser,
    required this.text,
    required this.timestamp,
    this.attachedExercise,
  });
}

/// Coach-only: chat interface with AI. Uses same ChatLayout as coach-client chat.
/// No attachments, no video. AI responses rendered as Markdown.
class CoachAiChatScreen extends StatefulWidget {
  final String clientId;
  final String clientName;

  const CoachAiChatScreen({
    super.key,
    required this.clientId,
    required this.clientName,
  });

  @override
  State<CoachAiChatScreen> createState() => _CoachAiChatScreenState();
}

class _CoachAiChatScreenState extends State<CoachAiChatScreen> {
  final _logger = getLogger(className: 'CoachAiChatScreen');
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_AiChatMessage> _messages = [];
  bool _isLoading = false;
  ExerciseDto? _attachedExercise;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isLoading) return;

    final exercise = _attachedExercise;

    _messageController.clear();
    setState(() {
      _attachedExercise = null;
      _messages.add(_AiChatMessage(
        isUser: true,
        text: text,
        timestamp: DateTime.now(),
        attachedExercise: exercise,
      ));
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final uri = Uri.parse(openAiBaseUrl).resolve(aiQueryPath);
      final body = <String, dynamic>{
        'query': text,
        'client_id': widget.clientId,
      };
      if (exercise != null) {
        body['exercise_ids'] = [exercise.id];
      }
      _logger.i(
          '[AI Chat] POST $uri query="$text" client_id=${widget.clientId} exercise_ids=${body['exercise_ids'] ?? 'null'}');

      final response = await http.post(
        uri,
        headers: notathletesAuthHeaders(),
        body: jsonEncode(body),
      );

      _logger.i(
          '[AI Chat] Response statusCode=${response.statusCode} body=${response.body.length > 500 ? "${response.body.substring(0, 500)}..." : response.body}');

      if (!mounted) return;

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body) as Map<String, dynamic>?;
        final answer = body?['answer'] as String?;
        final answerText = answer?.trim() ?? '';

        _logger.i('[AI Chat] Parsed answer length=${answerText.length}');

        setState(() {
          _messages.add(_AiChatMessage(
            isUser: false,
            text: answerText.isNotEmpty ? answerText : 'No response received.',
            timestamp: DateTime.now(),
          ));
          _isLoading = false;
        });
      } else {
        _logger.w(
            '[AI Chat] Non-200 status=${response.statusCode} body=${response.body}');
        _handleError();
      }
    } catch (e, stack) {
      _logger.e('[AI Chat] Request failed: $e', error: e, stackTrace: stack);
      if (mounted) _handleError();
    }

    if (mounted) _scrollToBottom();
  }

  void _handleError() {
    _logger.w('[AI Chat] Showing error bottom sheet');
    setState(() => _isLoading = false);
    showErrorBottomSheet(
      context: context,
      title: 'Something went wrong',
      message: 'Please try again later.',
    );
  }

  Future<void> _showExercisePicker() async {
    final exercise = await showExercisePickerForAiChat(context: context);
    if (exercise != null && mounted) {
      setState(() => _attachedExercise = exercise);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatTimestamp(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (messageDate == today) {
      return DateFormat('HH:mm').format(dateTime);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${DateFormat('HH:mm').format(dateTime)}';
    } else {
      return DateFormat('MMM d, HH:mm').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    final colors = theme.extension<TRKRColors>();

    // Same header leading style as coach-client chat (initials container)
    final headerLeading = Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            (colors?.vibrantAccent ?? Colors.green).withValues(alpha: 0.4),
            (colors?.vibrantAccent ?? Colors.green).withValues(alpha: 0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Icon(
        Icons.auto_awesome,
        size: 18,
        color: colors?.vibrantAccent ?? Colors.green,
      ),
    );

    return ChatLayout(
      headerLeading: headerLeading,
      title: 'Ask about ${widget.clientName}',
      headerActions: [
        IconButton(
          icon: FaIcon(
            FontAwesomeIcons.solidCircleXmark,
            color: isDarkMode ? Colors.white : Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
      messagesContent: _messages.isEmpty && !_isLoading
          ? ChatEmptyState(
              title: 'Ask about this client',
              subtitle: 'Get insights on training, nutrition, and progress.',
            )
          : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return _buildLoadingBubble(theme, isDarkMode);
                }
                final msg = _messages[index];
                return ChatTextBubble(
                  isCurrentUser: msg.isUser,
                  text: msg.text,
                  timestamp: _formatTimestamp(msg.timestamp),
                  isMarkdown: !msg.isUser,
                  attachedExerciseName: msg.attachedExercise?.name,
                  attachedExerciseId: msg.attachedExercise?.id,
                  attachedExerciseIsSystem:
                      msg.attachedExercise?.isSystem ?? false,
                );
              },
            ),
      messageController: _messageController,
      onSend: _sendMessage,
      isSending: _isLoading,
      showAttachmentButton: true,
      onAttachmentTap: _showExercisePicker,
      inputHint: 'Ask a question',
      widgetAboveInput: _attachedExercise != null
          ? _buildAttachedExerciseChip(context)
          : null,
    );
  }

  Widget _buildAttachedExerciseChip(BuildContext context) {
    final ex = _attachedExercise!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = Theme.of(context).extension<TRKRColors>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            height: 28,
            child: ex.isSystem
                ? FutureBuilder<String?>(
                    future: LottieExerciseRegistry.lottieFor(ex.id),
                    builder: (context, snapshot) {
                      final asset = snapshot.data;
                      if (asset != null) {
                        return Lottie.asset(
                          asset,
                          width: 28,
                          height: 28,
                          fit: BoxFit.contain,
                          repeat: true,
                        );
                      }
                      return Icon(
                        Icons.fitness_center,
                        size: 20,
                        color: colors?.vibrantAccent ?? Colors.green,
                      );
                    },
                  )
                : Icon(
                    Icons.fitness_center,
                    size: 20,
                    color: colors?.vibrantAccent ?? Colors.green,
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              ex.name,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.white70 : Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _attachedExercise = null),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                Icons.close,
                size: 18,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingBubble(ThemeData theme, bool isDarkMode) {
    final colors = theme.extension<TRKRColors>();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: (colors?.vibrantAccent ?? Colors.green)
                  .withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colors?.vibrantAccent ?? Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Thinking...',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the coach AI chat bottom sheet. Same presentation as coach-client chat.
void showCoachAiChatBottomSheet({required BuildContext context}) {
  final controller = context.read<ClientOverrideController>();
  final clientId = controller.selectedClientId;
  final clientName = controller.selectedClientName?.trim().isNotEmpty == true
      ? controller.selectedClientName!.trim()
      : 'this client';

  if (clientId == null || clientId.isEmpty) {
    showErrorBottomSheet(
      context: context,
      title: 'Select a client',
      message: 'Please select a client first to ask AI questions.',
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: false,
    useSafeArea: true,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    builder: (context) => Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context, rootNavigator: false).pop(),
            child: Container(color: Colors.transparent),
          ),
        ),
        AppBottomSheet(
          isDraggable: false,
          isDismissible: true,
          child: CoachAiChatScreen(
            clientId: clientId,
            clientName: clientName,
          ),
        ),
      ],
    ),
  );
}
