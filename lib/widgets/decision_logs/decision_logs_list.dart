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
  final Color? primaryTextColor;
  final Color? secondaryTextColor;

  const DecisionLogsList({
    super.key,
    required this.clientId,
    this.clientName,
    this.limit = 3,
    this.showTitle = true,
    this.showViewAll = true,
    this.onViewAll,
    this.primaryTextColor,
    this.secondaryTextColor,
  });

  @override
  State<DecisionLogsList> createState() => _DecisionLogsListState();
}

class _DecisionLogsListState extends State<DecisionLogsList> {
  final SupabaseCoachDecisionRepository _repo =
      SupabaseCoachDecisionRepository();
  late Future<List<CoachDecisionDto>> _decisionsFuture;

  String _capitalizeFirstSentence(String value) {
    final trimmed = value.trimLeft();
    if (trimmed.isEmpty) {
      return value.trim();
    }
    final first = trimmed.characters.first.toUpperCase();
    return '$first${trimmed.characters.skip(1).toString()}';
  }

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
    final primaryText = widget.primaryTextColor ?? theme.colorScheme.onSurface;
    final secondaryText = widget.secondaryTextColor ??
        theme.colorScheme.onSurface.withValues(alpha: 0.6);

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
                    color: secondaryText,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _capitalizeFirstSentence(decision.summary),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                    color: primaryText,
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
                    InkWell(
                      onTap: widget.onViewAll,
                      borderRadius: BorderRadius.circular(5),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          'View all updates',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.black.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
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
                'No updates yet.',
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
                                    color: secondaryText,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _capitalizeFirstSentence(decision.summary),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                    color: primaryText,
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
