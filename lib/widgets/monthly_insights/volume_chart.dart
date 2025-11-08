import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tracker_app/dtos/set_dtos/reps_dto.dart';
import 'package:tracker_app/extensions/datetime/datetime_extension.dart';
import 'package:tracker_app/utils/string_utils.dart';

import 'package:tracker_app/controllers/supabase_exercise_and_routine_controller.dart';
import '../../dtos/graph/chart_point_dto.dart';
import '../../dtos/set_dtos/weight_and_reps_dto.dart';
import '../../enums/chart_unit_enum.dart';
import '../../enums/exercise_type_enums.dart';
import '../../utils/data_trend_utils.dart';
import '../../utils/date_utils.dart';
import '../../utils/exercise_logs_utils.dart';
import '../../utils/general_utils.dart';
import '../chart/line_chart_widget.dart';

class VolumeChart extends StatelessWidget {
  const VolumeChart({super.key});

  @override
  Widget build(BuildContext context) {
    final routineLogController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);

    final dateRange = theLastYearDateTimeRange();

    final logs = routineLogController
        .whereLogsIsWithinRange(range: dateRange)
        .map((log) => routineWithLoggedExercises(log: log))
        .toList();

    final weeksInLastQuarter = generateWeeksInRange(range: dateRange)
        .reversed
        .take(13)
        .toList()
        .reversed;

    List<String> months = [];
    List<double> volumes = [];
    for (final week in weeksInLastQuarter) {
      final startOfWeek = week.start;
      final endOfWeek = week.end;
      final logsForTheWeek = logs.where((log) =>
          log.startTime.isBetweenInclusive(from: startOfWeek, to: endOfWeek));
      final values = logsForTheWeek
          .expand((log) => log.exerciseLogs)
          .expand((exerciseLog) => exerciseLog.sets)
          .map((set) {
            return switch (set.type) {
              ExerciseType.weights => (set as WeightAndRepsSetDto).volume(),
              ExerciseType.bodyWeight => (set as RepsSetDto).reps,
              ExerciseType.duration => 0,
            };
          })
          .sum
          .toDouble();
      volumes.add(values);
      months.add(startOfWeek.abbreviatedMonth());
    }

    final chartPoints = volumes
        .mapIndexed(
            (index, value) => ChartPointDto(index.toDouble(), value.toDouble()))
        .toList();

    final trendSummary = _analyzeWeeklyTrends(volumes: volumes);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          children: [
            trendSummary.trend == Trend.none
                ? const SizedBox.shrink()
                : getTrendIcon(trend: trendSummary.trend),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    text: volumeInKOrM(trendSummary.average),
                    style: Theme.of(context).textTheme.headlineSmall,
                    children: [
                      TextSpan(
                        text: " ",
                      ),
                      TextSpan(
                        text: weightUnit().toUpperCase(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                Text(
                  "Weekly AVERAGE".toUpperCase(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            )
          ],
        ),
        const SizedBox(height: 10),
        Text(trendSummary.summary,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w400)),
        const SizedBox(height: 20),
        LineChartWidget(
          chartPoints: chartPoints,
          periods: months,
          unit: ChartUnit.weight,
          hasLeftAxisTitles: false,
          aspectRation: 4,
          interval: 6,
        )
      ],
    );
  }

  TrendSummary _analyzeWeeklyTrends({required List<double> volumes}) {
    // 1. If there's no data at all, return immediately
    if (volumes.isEmpty) {
      return TrendSummary(
        trend: Trend.none,
        average: 0,
        summary:
            "🤔 No training data available yet. Log some sessions to start tracking your progress!",
      );
    }

    // 2. If there's only one volume, we can’t calculate “previous average”.
    //    So just return a simple summary here.
    if (volumes.length == 1) {
      // Here, “averageOfPrevious” doesn’t exist because there is no previous session.
      // So we can safely set it to 0 or the same singleVolume—whichever you prefer.
      return TrendSummary(
        trend: Trend.none,
        average: 0, // No previous sessions
        summary: "🌟 You've logged your first week's volume. "
            "Great job! Keep logging more data to see trends over time.",
      );
    }

    // 3. At this point, volumes.length >= 2, so we can safely do sublist and reduce
    final previousVolumes = volumes.sublist(0, volumes.length - 1);
    final averageOfPrevious =
        (previousVolumes.reduce((a, b) => a + b) / previousVolumes.length)
            .round();

    // 4. Identify the most recent volume
    final recentWeekVolume = volumes.last;

    if (recentWeekVolume == 0) {
      return TrendSummary(
        trend: Trend.none,
        average: averageOfPrevious,
        summary: "🤔 No training data available for this week. "
            "Log some workouts to continue tracking your progress!",
      );
    }

    // 5. Compare last week's volume to the average of previous volumes
    final difference = recentWeekVolume - averageOfPrevious;
    final differenceIsZero = difference == 0;

    // If the average is zero, treat it as a special case for percentage change
    final bool averageIsZero = averageOfPrevious == 0;
    final double percentageChange =
        averageIsZero ? 100.0 : (difference / averageOfPrevious) * 100;

    // 6. Decide the trend
    const threshold = 5; // ±5% threshold
    late final Trend trend;
    if (percentageChange > threshold) {
      trend = Trend.up;
    } else if (percentageChange < -threshold) {
      trend = Trend.down;
    } else {
      trend = Trend.stable;
    }

    // 7. Generate a friendly, concise message based on the trend
    final variation = "${percentageChange.abs().toStringAsFixed(1)}%";

    switch (trend) {
      case Trend.up:
        return TrendSummary(
          trend: Trend.up,
          average: averageOfPrevious,
          summary:
              "🌟🌟 This week's volume is $variation higher than your weekly average. "
              "Awesome job building momentum!",
        );

      case Trend.down:
        return TrendSummary(
          trend: Trend.down,
          average: averageOfPrevious,
          summary:
              "📉 This week's volume is $variation lower than your weekly average. "
              "Consider extra rest, checking your technique, or planning a deload.",
        );

      case Trend.stable:
        final summary = differenceIsZero
            ? "🌟 You've matched your weekly average! Stay consistent to see long-term progress."
            : "🔄 Your volume changed by about $variation compared to your average. "
                "A great chance to refine your form and maintain consistency.";
        return TrendSummary(
          trend: Trend.stable,
          average: averageOfPrevious,
          summary: summary,
        );

      case Trend.none:
        return TrendSummary(
          trend: Trend.none,
          average: averageOfPrevious,
          summary: "🤔 Unable to identify trends",
        );
    }
  }
}
