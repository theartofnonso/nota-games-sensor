import 'package:flutter/material.dart';

import '../controllers/exercise_and_routine_controller.dart';
import '../dtos/appsync/routine_log_dto.dart';

class NudgeEngine {
  /// Build an informational-only nudge for the Overview context.
  /// Returns null when no nudge should be shown.
  static String? buildOverviewNudge({
    required ExerciseAndRoutineController controller,
    DateTime? now,
  }) {
    final DateTime current = now ?? DateTime.now();

    // 1) Use last 90 days to learn patterns
    final DateTime ninetyDaysAgo = current.subtract(const Duration(days: 90));
    final DateTimeRange last90Days =
        DateTimeRange(start: ninetyDaysAgo, end: current);
    final List<RoutineLogDto> logs90 =
        controller.whereLogsIsWithinRange(range: last90Days);

    // Early out if there is no history at all
    if (logs90.isEmpty) return null;

    // 2) If no session today and we are within the user's common training window, nudge about timing
    final bool trainedToday =
        controller.whereLogsIsSameDay(dateTime: current).isNotEmpty;
    if (!trainedToday) {
      final int? peakHour = _mostCommonHour(logs90);
      if (peakHour != null) {
        final bool inWindow =
            _isWithinHourWindow(current.hour, peakHour, toleranceHours: 1);
        if (inWindow) {
          final String label = _formatHourLabel(peakHour);
          return "This is around your usual training time (~$label).";
        }
      }
    }

    // 3) If it's been several days since last session, provide a gentle consistency nudge
    final lastLog = controller.logs.isEmpty ? null : controller.logs.last;
    if (lastLog != null) {
      final int daysSince = current.difference(lastLog.createdAt).inDays;
      if (daysSince >= 3) {
        return "It’s been $daysSince days since your last session—light day could help momentum.";
      }
    }

    // 4) Weekly adherence reinforcement (informational)
    final DateTime startOfWeek = _startOfWeek(current);
    final DateTimeRange thisWeek =
        DateTimeRange(start: startOfWeek, end: current);
    final int sessionsThisWeek =
        controller.whereLogsIsWithinRange(range: thisWeek).length;
    if (sessionsThisWeek >= 2) {
      return "Nice consistency this week ($sessionsThisWeek sessions). Keep the rhythm.";
    }

    return null;
  }

  static int? _mostCommonHour(List<RoutineLogDto> logs90) {
    // access createdAt.hour safely
    final Map<int, int> countsByHour = {};
    for (final log in logs90) {
      final int hour = log.createdAt.hour;
      countsByHour.update(hour, (v) => v + 1, ifAbsent: () => 1);
    }
    if (countsByHour.isEmpty) return null;
    int bestHour = countsByHour.keys.first;
    int bestCount = countsByHour[bestHour]!;
    countsByHour.forEach((hour, count) {
      if (count > bestCount) {
        bestCount = count;
        bestHour = hour;
      }
    });
    return bestHour;
  }

  static bool _isWithinHourWindow(int currentHour, int targetHour,
      {int toleranceHours = 1}) {
    final int diff = (currentHour - targetHour).abs();
    return diff <= toleranceHours || diff >= (24 - toleranceHours);
  }

  static DateTime _startOfWeek(DateTime dt) {
    // ISO week starts on Monday
    final int weekday = dt.weekday; // Mon=1 ... Sun=7
    return DateTime(dt.year, dt.month, dt.day)
        .subtract(Duration(days: weekday - 1));
  }

  static String _formatHourLabel(int hour24) {
    final int h = hour24 % 24;
    final String suffix = h >= 12 ? 'pm' : 'am';
    final int hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return "$hour12$suffix";
  }
}
