import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/extensions/datetime/datetime_extension.dart';
import 'package:trainware/extensions/duration_extension.dart';
import 'package:trainware/utils/exercise_logs_utils.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/utils/string_utils.dart';

import '../../dtos/appsync/routine_log_dto.dart';
import '../../utils/theme/color_extensions.dart';
import '../logs/routine_log_screen.dart';

/// Client-only screen: chronological list of sessions where the coach has
/// left feedback. Sessions with notes are the priority display; all sessions
/// with notes are listed.
class CoachFeedbackFeedScreen extends StatelessWidget {
  static const routeName = '/coach_feedback_feed';

  const CoachFeedbackFeedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SupabaseExerciseAndRoutineController>();
    final logs = controller.logs;
    final withNotes = logs
        .where((log) =>
            log.coachNote != null && log.coachNote!.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => b.endTime.compareTo(a.endTime));

    return Scaffold(
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: themeGradient(context: context),
        ),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              AppBar(
                title: const Text('Coach feedback'),
                backgroundColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                leading: IconButton(
                  icon: const FaIcon(FontAwesomeIcons.solidCircleXmark, size: 28),
                  onPressed: () => context.pop(),
                ),
              ),
              Expanded(
                child: withNotes.isEmpty
                    ? _EmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        itemCount: withNotes.length,
                        itemBuilder: (context, index) {
                          final log = withNotes[index];
                          return _FeedbackCard(
                            log: log,
                            onTap: () => _openSession(context, log),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSession(BuildContext context, RoutineLogDto log) {
    context.push(RoutineLogScreen.routeName, extra: {
      'log': log,
      'isEditable': true,
      'showShareOnLoad': false,
    });
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(
              FontAwesomeIcons.solidCommentDots,
              size: 56,
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.25),
            ),
            const SizedBox(height: 20),
            Text(
              'No coach feedback yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'When your coach adds feedback to a session, it will appear here.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  final RoutineLogDto log;
  final VoidCallback onTap;

  const _FeedbackCard({
    required this.log,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateLabel = log.endTime.formattedDayMonthTime();
    final note = log.coachNote ?? '';

    final completedExercises = loggedExercises(exerciseLogs: log.exerciseLogs);
    final setCount = completedExercises.expand((e) => e.sets).length;
    final durationStr = log.duration().hmsAnalog();
    final volumeStr = log.volume > 0 ? volumeInKOrM(log.volume) : null;
    final summaryParts = <String>[
      '${completedExercises.length} exercise${completedExercises.length == 1 ? '' : 's'}',
      '$setCount set${setCount == 1 ? '' : 's'}',
      durationStr,
      if (volumeStr != null) volumeStr,
    ];
    final summaryLabel = summaryParts.join(' · ');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FaIcon(
                    FontAwesomeIcons.calendarDay,
                    size: 14,
                    color: theme.colors.vibrantAccent,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    dateLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                log.name,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                summaryLabel,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.55),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Text(
                note,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.85),
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
