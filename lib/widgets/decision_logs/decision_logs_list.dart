import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trainware/dtos/coach_decision_dto.dart';
import 'package:trainware/repositories/supabase/supabase_coach_decision_repository.dart';

class DecisionLogsList extends StatelessWidget {
  final String clientId;
  final String? clientName;
  final int limit;
  final bool showTitle;
  final bool showViewAll;
  final VoidCallback? onViewAll;

  const DecisionLogsList({
    super.key,
    required this.clientId,
    this.clientName,
    this.limit = 3,
    this.showTitle = true,
    this.showViewAll = true,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final repo = SupabaseCoachDecisionRepository();

    return FutureBuilder<List<CoachDecisionDto>>(
      future: repo.loadDecisions(clientId: clientId, limit: limit),
      builder: (context, snapshot) {
        final decisions = snapshot.data ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showTitle)
              Row(
                children: [
                  Text(
                    clientName == null || clientName!.isEmpty
                        ? 'Coaches decisions'
                        : 'Decisions for ${clientName!}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  if (showViewAll && onViewAll != null)
                    TextButton(
                      onPressed: onViewAll,
                      child: const Text('View all'),
                    ),
                ],
              ),
            if (showTitle) const SizedBox(height: 8),
            if (snapshot.connectionState == ConnectionState.waiting)
              const Center(child: CircularProgressIndicator())
            else if (snapshot.hasError)
              Text(
                'Failed to load decision logs.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                ),
              )
            else if (decisions.isEmpty)
              Text(
                'No decisions logged yet.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.grey.shade500,
                ),
              )
            else
              ...decisions.asMap().entries.map(
                (entry) {
                  final index = entry.key;
                  final decision = entry.value;
                  final timeLabel = DateFormat('MMM d, h:mm a')
                      .format(decision.createdAt.toLocal());
                  final isLast = index == decisions.length - 1;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.sticky_note_2_outlined,
                            size: 18,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                timeLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                decision.summary,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (!isLast) ...[
                                const SizedBox(height: 10),
                                Divider(
                                  color: Colors.white.withValues(alpha: 0.08),
                                  height: 1,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
