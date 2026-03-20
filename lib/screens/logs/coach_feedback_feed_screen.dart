import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/widgets/navigation/app_floating_navigation_bar.dart';

import '../../dtos/appsync/routine_log_dto.dart';
import '../logs/routine_log_screen.dart';

/// Client-only screen: chronological list of sessions where the coach has
/// left feedback. Sessions with notes are the priority display; all sessions
/// with notes are listed.
class CoachFeedbackFeedScreen extends StatelessWidget {
  static const routeName = '/coach_feedback_feed';

  /// When true (main shell tab), hide close; use bottom nav. Reserve space above nav bar.
  final bool embeddedInShell;

  const CoachFeedbackFeedScreen({
    super.key,
    this.embeddedInShell = false,
  });

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SupabaseExerciseAndRoutineController>();
    final logs = controller.logs;
    final withNotes = logs
        .where((log) =>
            log.coachNote != null && log.coachNote!.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => b.endTime.compareTo(a.endTime));

    final bottomNavPad = embeddedInShell
        ? MediaQuery.paddingOf(context).bottom + kAppFloatingNavBarReserveHeight
        : 0.0;

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
                automaticallyImplyLeading: !embeddedInShell,
                leading: embeddedInShell
                    ? null
                    : IconButton(
                        icon: const FaIcon(
                            FontAwesomeIcons.solidCircleXmark,
                            size: 28),
                        onPressed: () => context.pop(),
                      ),
              ),
              Expanded(
                child: withNotes.isEmpty
                    ? Padding(
                        padding: EdgeInsets.only(bottom: bottomNavPad),
                        child: _EmptyState(),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.fromLTRB(0, 8, 0, 8 + bottomNavPad),
                        itemCount: withNotes.length,
                        itemBuilder: (context, index) {
                          final log = withNotes[index];
                          return _FeedbackCard(
                            index: index,
                            totalCount: withNotes.length,
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
    final muted =
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: FaIcon(
                FontAwesomeIcons.solidCommentDots,
                size: 48,
                color: muted,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No coach feedback yet',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'When your coach adds feedback to a session, it will appear here as a note.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: muted,
                height: 1.4,
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
  final int index;
  final int totalCount;
  final RoutineLogDto log;
  final VoidCallback onTap;

  const _FeedbackCard({
    required this.index,
    required this.totalCount,
    required this.log,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final note = log.coachNote ?? '';
    final noteSnippet =
        note.length > 120 ? '${note.substring(0, 120).trim()}…' : note;

    final primaryColor = isDark ? Colors.white : Colors.black87;
    final secondaryColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5);
    final dividerColor = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12);

    final indexLabel =
        '${(index + 1).toString().padLeft(2, '0')}/$totalCount';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (index > 0) ...[
          Divider(
            height: 1,
            thickness: 1,
            color: dividerColor,
          ),
          const SizedBox(height: 20),
        ] else
          const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              indexLabel,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: secondaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                log.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w600,
                                  height: 1.2,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.only(left: 0),
                          child: Text(
                            noteSnippet,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: secondaryColor,
                              height: 1.45,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.open_in_new_rounded,
                      size: 20,
                      color: primaryColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}
