import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trainware/dtos/coach_decision_dto.dart';
import 'package:trainware/repositories/supabase/supabase_coach_decision_repository.dart';
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';

class DecisionLogsList extends StatefulWidget {
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
  State<DecisionLogsList> createState() => _DecisionLogsListState();
}

class _DecisionLogsListState extends State<DecisionLogsList> {
  final SupabaseCoachDecisionRepository _repo =
      SupabaseCoachDecisionRepository();
  late Future<List<CoachDecisionDto>> _decisionsFuture;

  @override
  void initState() {
    super.initState();
    _decisionsFuture =
        _repo.loadDecisions(clientId: widget.clientId, limit: widget.limit);
  }

  @override
  void didUpdateWidget(covariant DecisionLogsList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clientId != widget.clientId ||
        oldWidget.limit != widget.limit) {
      _decisionsFuture =
          _repo.loadDecisions(clientId: widget.clientId, limit: widget.limit);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    void showDecisionDetails(CoachDecisionDto decision) {
      final timeLabel =
          DateFormat('MMM d, h:mm a').format(decision.createdAt.toLocal());
      showAppBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: true,
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: SizedBox(
            width: double.infinity,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Decision details',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  timeLabel,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  decision.summary,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return FutureBuilder<List<CoachDecisionDto>>(
      future: _decisionsFuture,
      builder: (context, snapshot) {
        final decisions = snapshot.data ?? const [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showTitle)
              Row(
                children: [
                  if (widget.showViewAll && widget.onViewAll != null)
                    TextButton(
                      onPressed: widget.onViewAll,
                      child: const Text('View all updates'),
                    ),
                  const Spacer(),
                ],
              ),
            if (widget.showTitle) const SizedBox(height: 8),
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
                  return InkWell(
                    onTap: () => showDecisionDetails(decision),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
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
