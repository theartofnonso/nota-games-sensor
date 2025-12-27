import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:trainware/controllers/exercise_log_controller.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';
import 'package:trainware/dtos/routine_timeline_event_dto.dart';

class WorkoutRecapScreen extends StatelessWidget {
  final RoutineLogDto log;

  const WorkoutRecapScreen({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Yesterday’s recap'),
      ),
      body: FutureBuilder<List<RoutineTimelineEventDto>>(
        future: context.read<ExerciseLogController>().timelineForLog(log.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text('Could not load recap'),
            );
          }
          final List<RoutineTimelineEventDto> events =
              List<RoutineTimelineEventDto>.of(
                  snapshot.data ?? const <RoutineTimelineEventDto>[])
                ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
          if (events.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No timeline events were captured for this session.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final stats = _stats(events);

          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            children: [
              _StatsCard(
                sessionDuration: log.duration(),
                uniqueExercises: stats.uniqueExercises,
                setsCompleted: stats.setsCompleted,
              ),
              const SizedBox(height: 12),
              ...List.generate(events.length, (index) {
                final event = events[index];
                final timeLabel = DateFormat.Hm().format(event.timestamp);
                return Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 64,
                          child: Text(
                            timeLabel,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                event.summary,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (event.metadata != null &&
                                  event.metadata!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    _metadataLabel(event),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: Colors.white60),
                                  ),
                                ),
                            ],
                          ),
                        )
                      ],
                    ),
                    if (index != events.length - 1)
                      const Divider(height: 16),
                  ],
                );
              }),
            ],
          );
        },
      ),
    );
  }

  String _metadataLabel(RoutineTimelineEventDto event) {
    final meta = event.metadata ?? {};
    if (meta.containsKey('weight') && meta.containsKey('reps')) {
      return '${meta['weight']} × ${meta['reps']}';
    }
    if (meta.containsKey('reps')) {
      return '${meta['reps']} reps';
    }
    if (meta.containsKey('durationMs')) {
      final seconds = (meta['durationMs'] as int) ~/ 1000;
      final minutes = seconds ~/ 60;
      final remSeconds = seconds % 60;
      return '${minutes}m ${remSeconds}s';
    }
    return '';
  }

  _RecapStats _stats(List<RoutineTimelineEventDto> events) {
    final exerciseNames = <String>{};
    int setsCompleted = 0;
    for (final e in events) {
      if (e.exerciseName != null) {
        exerciseNames.add(e.exerciseName!);
      }
      if (e.action == 'check_set' && (e.checked ?? false)) {
        setsCompleted++;
      }
    }
    return _RecapStats(
      uniqueExercises: exerciseNames.length,
      setsCompleted: setsCompleted,
    );
  }
}

class _RecapStats {
  final int uniqueExercises;
  final int setsCompleted;

  const _RecapStats({
    required this.uniqueExercises,
    required this.setsCompleted,
  });
}

class _StatsCard extends StatelessWidget {
  final Duration sessionDuration;
  final int uniqueExercises;
  final int setsCompleted;

  const _StatsCard({
    required this.sessionDuration,
    required this.uniqueExercises,
    required this.setsCompleted,
  });

  @override
  Widget build(BuildContext context) {
    String durationLabel() {
      final h = sessionDuration.inHours;
      final m = sessionDuration.inMinutes % 60;
      if (h > 0) return '${h}h ${m}m';
      return '${m}m';
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _StatItem(label: 'Duration', value: durationLabel()),
          _StatItem(label: 'Exercises', value: uniqueExercises.toString()),
          _StatItem(label: 'Sets done', value: setsCompleted.toString()),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;

  const _StatItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.white70),
        ),
      ],
    );
  }
}

