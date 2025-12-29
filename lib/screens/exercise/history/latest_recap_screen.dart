import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:trainware/dtos/routine_timeline_event_dto.dart';

class LatestRecapScreen extends StatelessWidget {
  final List<RoutineTimelineEventDto> events;
  final String? logId;
  final bool asSheet;
  final ScrollController? scrollController;

  const LatestRecapScreen({
    super.key,
    required this.events,
    this.logId,
    this.asSheet = false,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final sorted = List<RoutineTimelineEventDto>.of(events)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final content = sorted.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No recap available yet.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
            ),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final event = sorted[index];
                    final isFirst = index == 0;
                    final isLast = index == sorted.length - 1;
                    final sessionStart = sorted.first.timestamp;

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Timeline gutter with icon
                          Column(
                            children: [
                              // Top connector line
                              if (!isFirst)
                                Container(
                                  width: 2,
                                  height: 12,
                                  color: Colors.white24,
                                ),
                              // Icon only (no circle)
                              SizedBox(
                                width: 48,
                                height: 48,
                                child: Center(
                                  child: FaIcon(
                                    _iconFor(event),
                                    size: 16,
                                    color: _colorFor(event),
                                  ),
                                ),
                              ),
                              // Bottom connector line
                              if (!isLast)
                                Expanded(
                                  child: Container(
                                    width: 1,
                                    color: Colors.white24,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          // Content
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSummaryText(context, event),
                                  const SizedBox(height: 4),
                                  Text(
                                    _formatRelativeTime(
                                        event.timestamp, sessionStart),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );

    if (asSheet) {
      return SafeArea(bottom: false, child: content);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1220),
        elevation: 0,
        surfaceTintColor: const Color(0xFF0F1220),
        title: const Text(
          'Workout Recap',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: content,
    );
  }

  Widget _buildSummaryText(
      BuildContext context, RoutineTimelineEventDto event) {
    // Parse the summary to highlight exercise names and important parts
    final summary = event.summary;
    final exerciseName = event.exerciseName;

    if (exerciseName != null && summary.contains(exerciseName)) {
      final parts = summary.split(exerciseName);
      return RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 15,
            color: Colors.white,
            height: 1.4,
          ),
          children: [
            TextSpan(text: parts[0]),
            TextSpan(
              text: exerciseName,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            if (parts.length > 1) TextSpan(text: parts[1]),
          ],
        ),
      );
    }

    return Text(
      summary,
      style: const TextStyle(
        fontSize: 15,
        color: Colors.white,
        height: 1.4,
      ),
    );
  }

  String _formatRelativeTime(DateTime timestamp, DateTime sessionStart) {
    if (timestamp.isAtSameMomentAs(sessionStart)) return 'Start';

    final difference = timestamp.difference(sessionStart);
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s later';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m later';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h later';
    } else if (difference.inDays == 1) {
      return '1 day later';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days later';
    } else {
      return '${difference.inDays ~/ 7} weeks later';
    }
  }

  Color _colorFor(RoutineTimelineEventDto event) {
    switch (event.action) {
      case 'session_start':
        return Colors.green;
      case 'add_exercise':
        return Colors.blue;
      case 'remove_exercise':
        return Colors.red;
      case 'check_set':
        return Colors.green;
      case 'uncheck_set':
        return Colors.orange;
      case 'add_set':
        return Colors.purple;
      case 'update_set_weight':
        return Colors.indigo;
      case 'update_set_reps':
        return Colors.teal;
      case 'update_set_duration':
        return Colors.cyan;
      case 'session_end':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _iconFor(RoutineTimelineEventDto event) {
    switch (event.action) {
      case 'session_start':
        return FontAwesomeIcons.play;
      case 'add_exercise':
        return FontAwesomeIcons.plus;
      case 'remove_exercise':
        return FontAwesomeIcons.minus;
      case 'check_set':
        return FontAwesomeIcons.check;
      case 'uncheck_set':
        return FontAwesomeIcons.arrowRotateLeft;
      case 'add_set':
        return FontAwesomeIcons.hashtag;
      case 'update_set_weight':
        return FontAwesomeIcons.weightHanging;
      case 'update_set_reps':
        return FontAwesomeIcons.repeat;
      case 'update_set_duration':
        return FontAwesomeIcons.clock;
      case 'session_end':
        return FontAwesomeIcons.flagCheckered;
      default:
        return FontAwesomeIcons.circleInfo;
    }
  }

}

