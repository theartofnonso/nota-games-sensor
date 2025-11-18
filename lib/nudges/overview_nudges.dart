import 'package:flutter/material.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';

class OverviewNudges {
  static String? build({
    required SupabaseExerciseAndRoutineController controller,
    DateTime? now,
  }) {
    final DateTime current = now ?? DateTime.now();
    final DateTime ninetyDaysAgo = current.subtract(const Duration(days: 90));
    final DateTimeRange last90Days =
        DateTimeRange(start: ninetyDaysAgo, end: current);
    final logs90 = controller.whereLogsIsWithinRange(dateRange: last90Days);

    if (logs90.isEmpty) return null;

    final trainedToday =
        controller.whereLogsIsSameDay(dateTime: current).isNotEmpty;

    if (!trainedToday) {
      final peakHour = _mostCommonHour(logs90.map((l) => l.startTime.hour));
      if (peakHour != null) {
        final inWindow =
            _isWithinHourWindow(current.hour, peakHour, toleranceHours: 1);
        if (inWindow) {
          final label = _formatHourLabel(peakHour);
          return "This is around your usual training time (~$label).";
        }
      }
    }

    final lastLog = controller.logs.isEmpty ? null : controller.logs.last;
    if (lastLog != null) {
      final daysSince = current.difference(lastLog.startTime).inDays;
      if (daysSince >= 3) {
        return "It's been $daysSince days since your last session—light day could help momentum.";
      }
    }

    final startOfWeek = _startOfWeek(current);
    final thisWeek = DateTimeRange(start: startOfWeek, end: current);
    final sessionsThisWeek =
        controller.whereLogsIsWithinRange(dateRange: thisWeek).length;

    if (sessionsThisWeek >= 2) {
      return "Nice consistency this week ($sessionsThisWeek sessions). Keep the rhythm.";
    }

    return null;
  }

  static int? _mostCommonHour(Iterable<int> hours) {
    final Map<int, int> counts = {};
    for (final h in hours) {
      counts.update(h, (v) => v + 1, ifAbsent: () => 1);
    }
    if (counts.isEmpty) return null;

    int bestHour = counts.keys.first;
    int bestCount = counts[bestHour]!;
    counts.forEach((hour, count) {
      if (count > bestCount) {
        bestCount = count;
        bestHour = hour;
      }
    });
    return bestHour;
  }

  static bool _isWithinHourWindow(int currentHour, int targetHour,
      {int toleranceHours = 1}) {
    final diff = (currentHour - targetHour).abs();
    return diff <= toleranceHours || diff >= (24 - toleranceHours);
  }

  static DateTime _startOfWeek(DateTime dt) {
    final weekday = dt.weekday; // Mon=1 ... Sun=7
    return DateTime(dt.year, dt.month, dt.day)
        .subtract(Duration(days: weekday - 1));
  }

  static String _formatHourLabel(int hour24) {
    final h = hour24 % 24;
    final suffix = h >= 12 ? 'pm' : 'am';
    final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return "$hour12$suffix";
  }
}
