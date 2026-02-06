import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../controllers/supabase_exercise_and_routine_controller.dart';
import '../../dtos/appsync/routine_log_dto.dart';
import '../../extensions/datetime/datetime_extension.dart';
import '../../screens/logs/coach_feedback_feed_screen.dart';
import '../cards/frosted_card.dart';

/// Client-only: shows the latest coach feedback as a note card when present.
/// Hidden when there are no coach notes. Tapping opens the full coach feedback feed.
class CoachFeedbackCard extends StatelessWidget {
  const CoachFeedbackCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SupabaseExerciseAndRoutineController>(
      builder: (context, controller, _) {
        final withNotes = controller.logs
            .where((log) =>
                log.coachNote != null && log.coachNote!.trim().isNotEmpty)
            .toList()
          ..sort((a, b) => b.endTime.compareTo(a.endTime));
        final latest = withNotes.isEmpty ? null : withNotes.first;
        if (latest == null) return const SizedBox.shrink();

        final theme = Theme.of(context);
        // Purple for coach feedback (distinct from green progress / blue hours cards)
        const feedbackAccent = Color(0xFF7C3AED);

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => context.push(CoachFeedbackFeedScreen.routeName),
              borderRadius: BorderRadius.circular(20),
              child: FrostedCard(
                borderRadius: 20,
                padding: const EdgeInsets.all(20),
                gradientColors: [
                  feedbackAccent.withValues(alpha: 0.35),
                  feedbackAccent.withValues(alpha: 0.15),
                  Colors.black.withValues(alpha: 0.45),
                ],
                child: _LatestNoteContent(
                  log: latest,
                  theme: theme,
                  accent: feedbackAccent,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LatestNoteContent extends StatelessWidget {
  final RoutineLogDto log;
  final ThemeData theme;
  final Color accent;

  const _LatestNoteContent({
    required this.log,
    required this.theme,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final dateLabel = log.endTime.formattedDayMonthTime();
    final note = log.coachNote ?? '';
    final notePreview =
        note.length > 140 ? '${note.substring(0, 140).trim()}…' : note;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Label row
        Row(
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.9),
            ),
            const SizedBox(width: 6),
            Text(
              'Coach feedback',
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Session name
        Text(
          log.name,
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          dateLabel,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 14),
        // Note quote block
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: accent.withValues(alpha: 0.8),
                width: 3,
              ),
            ),
          ),
          child: Text(
            notePreview,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.95),
              height: 1.45,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(height: 14),
        // View all CTA
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'View all feedback',
              style: theme.textTheme.labelMedium?.copyWith(
                color: Colors.white.withValues(alpha: 0.95),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.arrow_forward_rounded,
              size: 16,
              color: Colors.white.withValues(alpha: 0.95),
            ),
          ],
        ),
      ],
    );
  }
}
