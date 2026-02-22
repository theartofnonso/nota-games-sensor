import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';
import 'package:trainware/dtos/challenges/exercise_challenge_dto.dart';
import 'package:trainware/utils/lottie_exercise_registry.dart';
import 'package:trainware/widgets/cards/frosted_card.dart';

class ExerciseChallengeCard extends StatelessWidget {
  final ExerciseChallengeDto challenge;
  final ExerciseChallengeProgress progress;
  final bool canDelete;
  final bool pinProgressToBottom;
  final Future<void> Function()? onDelete;

  const ExerciseChallengeCard({
    super.key,
    required this.challenge,
    required this.progress,
    this.canDelete = false,
    this.pinProgressToBottom = false,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateUtils.dateOnly(DateTime.now());
    final rawDaysLeft = DateUtils.dateOnly(challenge.endDate).difference(now).inDays;
    final daysLeft = rawDaysLeft < 0 ? 0 : rawDaysLeft;
    final countdownLabel =
        rawDaysLeft <= 0 ? 'ended' : '${daysLeft == 1 ? 'day' : 'days'} left';
    final card = FrostedCard(
      gradientColors: [
        Colors.white.withValues(alpha: 0.9),
        Colors.white.withValues(alpha: 0.8),
        Colors.white.withValues(alpha: 0.7),
      ],
      child: Row(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final canPinToBottom =
                    pinProgressToBottom && constraints.hasBoundedHeight;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      challenge.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Colors.black.withValues(alpha: 0.85),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat('MMM d').format(challenge.startDate)} - ${DateFormat('MMM d').format(challenge.endDate)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.black.withValues(alpha: 0.6),
                          ),
                    ),
                    if (canPinToBottom) const Spacer() else const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$daysLeft',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                                    color: Colors.black.withValues(alpha: 0.9),
                                    fontWeight: FontWeight.w900,
                                    height: 1.0,
                                    fontSize: 28,
                                  ) ??
                              TextStyle(
                                color: Colors.black.withValues(alpha: 0.9),
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                height: 1.0,
                                fontFamily: 'Grift',
                              ),
                        ),
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            countdownLabel,
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.black.withValues(alpha: 0.7),
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: LinearProgressIndicator(
                        value: progress.percent,
                        minHeight: 6,
                        backgroundColor: Colors.black.withValues(alpha: 0.12),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${(progress.percent * 100).round()}% - ${_valueLabel(progress.bestValue, challenge.targetType)} / ${_valueLabel(progress.targetValue, challenge.targetType)}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Colors.black.withValues(alpha: 0.7),
                          ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 88,
            child: FutureBuilder<String?>(
              future: LottieExerciseRegistry.lottieFor(challenge.exerciseId),
              builder: (context, snapshot) {
                final path = snapshot.data;
                if (path != null && path.isNotEmpty) {
                  return Lottie.asset(path, fit: BoxFit.contain, repeat: true);
                }
                return Icon(
                  Icons.fitness_center,
                  color: Colors.black.withValues(alpha: 0.5),
                  size: 34,
                );
              },
            ),
          ),
        ],
      ),
    );

    if (!canDelete || onDelete == null) return card;

    return Dismissible(
      key: ValueKey(challenge.id),
      direction: DismissDirection.endToStart,
      background: const SizedBox.shrink(),
      confirmDismiss: (_) async {
        await onDelete!();
        return false;
      },
      child: card,
    );
  }
}

String _valueLabel(double value, ExerciseChallengeTargetType targetType) {
  switch (targetType) {
    case ExerciseChallengeTargetType.weight:
      return '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 1)}kg';
    case ExerciseChallengeTargetType.reps:
      return '${value.round()} reps';
    case ExerciseChallengeTargetType.duration:
      return '${value.round()}s';
  }
}
