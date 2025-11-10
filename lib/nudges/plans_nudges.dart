import 'package:flutter/material.dart';
import 'package:tracker_app/controllers/supabase_exercise_and_routine_controller.dart';
import '../utils/date_utils.dart';

class PlansNudges {
  static String? build({
    required SupabaseExerciseAndRoutineController controller,
    DateTime? now,
  }) {
    final DateTime current = now ?? DateTime.now();
    
    // This week (rolling 7 days)
    final DateTime sevenDaysAgo = current.subtract(const Duration(days: 7));
    final DateTimeRange thisWeek = DateTimeRange(start: sevenDaysAgo, end: current);
    final int sessionsThisWeek = controller.whereLogsIsWithinRange(dateRange: thisWeek).length;
    
    // Compute average sessions/week over the last quarter, excluding the current week
    final DateTimeRange lastQuarter = lastQuarterDateTimeRange();
    final List<DateTimeRange> weeksInLastQuarter = generateWeeksInRange(range: lastQuarter).toList();
    
    // Exclude the potentially partial current week
    final List<DateTimeRange> fullPastWeeks = weeksInLastQuarter.isNotEmpty
        ? weeksInLastQuarter.sublist(0, weeksInLastQuarter.length - 1)
        : const [];
        
    if (fullPastWeeks.isEmpty) {
      // No history to infer average
      if (sessionsThisWeek < 2) {
        return "Two short sessions this week can keep momentum.";
      }
      return null;
    }
    
    int totalSessions = 0;
    for (final week in fullPastWeeks) {
      totalSessions += controller.whereLogsIsWithinRange(dateRange: week).length;
    }
    
    final double avgSessions = totalSessions / fullPastWeeks.length;
    final int threshold = avgSessions.round().clamp(1, 7);
    
    if (sessionsThisWeek < threshold) {
      return "Two short sessions this week can keep momentum.";
    }
    
    return null;
  }
}
