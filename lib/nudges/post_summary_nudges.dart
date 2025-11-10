import 'package:flutter/material.dart';
import 'package:tracker_app/controllers/supabase_exercise_and_routine_controller.dart';
import '../dtos/appsync/routine_log_dto.dart';

class PostSummaryNudges {
  static String? build({
    required SupabaseExerciseAndRoutineController controller,
    required RoutineLogDto log,
    DateTime? now,
  }) {
    final DateTime current = now ?? DateTime.now();
    final DateTime twentyEightDaysAgo = current.subtract(const Duration(days: 28));
    final DateTimeRange last28 = DateTimeRange(start: twentyEightDaysAgo, end: current);
    final recent = controller.whereLogsIsWithinRange(dateRange: last28);
    
    if (recent.isEmpty) return null;
    
    double avgVolume = 0;
    for (final r in recent) {
      avgVolume += r.volume;
    }
    avgVolume = avgVolume / recent.length;
    
    if (avgVolume <= 0) return null;
    
    final double delta = ((log.volume - avgVolume) / avgVolume) * 100.0;
    
    if (delta >= 10) {
      return "Volume above recent average (≈ ${delta.toStringAsFixed(0)}%). Consider a lighter day next session.";
    } else if (delta <= -10) {
      return "Volume below recent average (≈ ${delta.abs().toStringAsFixed(0)}%). Add a small set next time if recovered.";
    }
    
    return "Steady volume vs recent average. Keep rest consistent for better density.";
  }
}
