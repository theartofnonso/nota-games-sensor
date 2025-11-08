import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tracker_app/extensions/datetime/datetime_extension.dart';
import 'package:tracker_app/utils/string_utils.dart';

import 'package:tracker_app/controllers/supabase_exercise_and_routine_controller.dart';
import '../../dtos/graph/chart_point_dto.dart';
import '../../enums/chart_unit_enum.dart';
import '../../utils/data_trend_utils.dart';
import '../../utils/date_utils.dart';
import '../../utils/general_utils.dart';
import '../chart/line_chart_widget.dart';

class LogStreakChart extends StatelessWidget {
  const LogStreakChart({super.key});

  @override
  Widget build(BuildContext context) {
    final routineLogController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);

    final dateRange = theLastYearDateTimeRange();

    final logs =
        routineLogController.whereLogsIsWithinRange(range: dateRange).toList();

    final weeksInLastQuarter = generateWeeksInRange(range: dateRange)
        .reversed
        .take(13)
        .toList()
        .reversed;

    List<String> months = [];
    List<int> days = [];
    for (final week in weeksInLastQuarter) {
      final startOfWeek = week.start;
      final endOfWeek = week.end;
      final logsForTheWeek = logs.where((log) =>
          log.startTime.isBetweenInclusive(from: startOfWeek, to: endOfWeek));
      final routineLogsByDay =
          groupBy(logsForTheWeek, (log) => log.startTime.withoutTime().day);
      days.add(routineLogsByDay.length);
      months.add(startOfWeek.abbreviatedMonth());
    }

    final chartPoints = days
        .mapIndexed(
            (index, value) => ChartPointDto(index.toDouble(), value.toDouble()))
        .toList();

    final trendSummary = _analyzeWeeklyTrends(daysTrained: days);

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
                    text: "${trendSummary.average}",
                    style: Theme.of(context).textTheme.headlineSmall,
                    children: [
                      TextSpan(
                        text: " ",
                      ),
                      TextSpan(
                        text: "days".toUpperCase(),
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
        const SizedBox(height: 30),
        LineChartWidget(
          chartPoints: chartPoints,
          periods: months,
          unit: ChartUnit.number,
          aspectRation: 4,
          hasLeftAxisTitles: false,
          interval: 6,
        )
      ],
    );
  }

  TrendSummary _analyzeWeeklyTrends({required List<int> daysTrained}) {
    // 1. If there's no data, return immediately
    if (daysTrained.isEmpty) {
      return TrendSummary(
        trend: Trend.none,
        average: 0,
        summary:
            "🤔 No training data available yet. Log some sessions to start tracking your progress!",
      );
    }

    // 2. If there's only one data point, avoid sublist/reduce on an empty list
    if (daysTrained.length == 1) {
      final singleWeek = daysTrained.first;
      // With only one data point, there's no "previous" data to average
      return TrendSummary(
        trend: Trend.none,
        average: 0,
        summary:
            "🌟 You’ve logged your first week: $singleWeek day(s) of training."
            " Great job! Log more weeks to identify trends over time.",
      );
    }

    // 3. Now we can safely do sublist & reduce because we have at least 2 entries
    final previousDays = daysTrained.sublist(0, daysTrained.length - 1);
    final averageOfPrevious =
        (previousDays.reduce((a, b) => a + b) / previousDays.length).round();

    // 4. Identify the last week's days trained
    final recentWeekDays = daysTrained.last;

    if (recentWeekDays == 0) {
      return TrendSummary(
        trend: Trend.none,
        average: averageOfPrevious,
        summary: "🤔 No training data available for this week. "
            "Log some sessions to continue tracking your progress!",
      );
    }

    // 5. Compare the last week's volume to the average of previous weeks
    final difference = recentWeekDays - averageOfPrevious;
    final differenceIsZero = (difference == 0);

    final bool averageIsZero = (averageOfPrevious == 0);
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

    // 7. Generate a concise message
    final diffAbs = difference.abs().toInt();

    switch (trend) {
      case Trend.up:
        return TrendSummary(
          trend: Trend.up,
          average: averageOfPrevious,
          summary:
              "🌟🌟 You're training $diffAbs more ${pluralize(word: 'day', count: diffAbs)} than your weekly average!"
              " Keep it going—you’re building solid habits!",
        );

      case Trend.down:
        return TrendSummary(
          trend: Trend.down,
          average: averageOfPrevious,
          summary:
              "📉 You're training $diffAbs ${pluralize(word: 'day', count: diffAbs)} lesser than your weekly average."
              " Consider your schedule, rest, or motivation to stay on track.",
        );

      case Trend.stable:
        final summary = differenceIsZero
            ? "🌟 You've matched your weekly average! Stay consistent to see long-term progress."
            : "🔄 Your training days only varied by about $diffAbs compared to your average."
                " Keep refining your routine for ongoing consistency!";
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
