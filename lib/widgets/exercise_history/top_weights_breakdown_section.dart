import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:trainware/dtos/appsync/exercise_dto.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';
import 'package:trainware/dtos/graph/chart_point_dto.dart';
import 'package:trainware/dtos/set_dtos/weight_and_reps_dto.dart';
import 'package:trainware/extensions/datetime/datetime_extension.dart';
import 'package:trainware/utils/exercise_logs_utils.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/widgets/chart/line_chart_widget.dart';

import '../../enums/chart_unit_enum.dart';
import '../../enums/exercise_type_enums.dart';

/// A section showing breakdown by top 3 weights – how reps increase or
/// decrease at each weight over time. Uses iOS segmented control.
/// Only shown for weight-based exercises when there is logged weight data.
class TopWeightsBreakdownSection extends StatefulWidget {
  final ExerciseDto exercise;
  final List<ExerciseLogDto> exerciseLogs;
  final ExerciseType selectedType;

  const TopWeightsBreakdownSection({
    super.key,
    required this.exercise,
    required this.exerciseLogs,
    required this.selectedType,
  });

  @override
  State<TopWeightsBreakdownSection> createState() =>
      _TopWeightsBreakdownSectionState();
}

class _TopWeightsBreakdownSectionState
    extends State<TopWeightsBreakdownSection> {
  int _selectedWeightIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (!withWeightsOnly(type: widget.selectedType)) {
      return const SizedBox.shrink();
    }

    final topWeights = getTopWeights(
      exerciseLogs: widget.exerciseLogs,
      count: 3,
    );
    if (topWeights.isEmpty) return const SizedBox.shrink();

    if (_selectedWeightIndex >= topWeights.length) {
      _selectedWeightIndex = 0;
    }

    final selectedWeight = topWeights[_selectedWeightIndex];
    final entries = getEntriesForWeightMaxRepsPerSession(
      exerciseLogs: widget.exerciseLogs,
      weight: selectedWeight,
    );
    if (entries.isEmpty) {
      return _buildSection(
        topWeights: topWeights,
        child: const _EmptyTopWeightsBreakdown(),
      );
    }

    return _buildSection(
      topWeights: topWeights,
      child: _TopWeightsBreakdownContent(
        exerciseLogs: widget.exerciseLogs,
        topWeights: topWeights,
        entries: entries,
        selectedWeightIndex: _selectedWeightIndex,
      ),
    );
  }

  Widget _buildSection({
    required List<double> topWeights,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unitLabel = weightUnit();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Divider(thickness: 1, color: Colors.white.withValues(alpha: 0.1)),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Reps by weights',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: topWeights.length >= 2
              ? CupertinoSlidingSegmentedControl<int>(
                  groupValue: _selectedWeightIndex,
                  backgroundColor: isDark
                      ? Theme.of(context).colors.sapphireDark
                      : Colors.grey.shade400,
                  thumbColor: isDark
                      ? Theme.of(context).colors.sapphireDark80
                      : Colors.white,
                  children: {
                    for (var i = 0; i < topWeights.length; i++)
                      i: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                        child: Text(
                          '${topWeights[i]}$unitLabel',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  },
                  onValueChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedWeightIndex = value);
                    }
                  },
                )
              : Text(
                  '${topWeights[0]}$unitLabel',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                ),
        ),
        const SizedBox(height: 20),
        child,
      ],
    );
  }
}

class _TopWeightsBreakdownContent extends StatelessWidget {
  final List<ExerciseLogDto> exerciseLogs;
  final List<double> topWeights;
  final List<(ExerciseLogDto, WeightAndRepsSetDto, int)> entries;
  final int selectedWeightIndex;

  const _TopWeightsBreakdownContent({
    required this.exerciseLogs,
    required this.topWeights,
    required this.entries,
    required this.selectedWeightIndex,
  });

  @override
  Widget build(BuildContext context) {
    final chartData = entries.map((e) => e.$2.reps.toDouble()).toList();
    final periods =
        entries.map((e) => e.$1.createdAt.formattedDayAndMonth()).toList();
    final chartPoints = chartData
        .asMap()
        .entries
        .map((e) => ChartPointDto(e.key, e.value))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 20, bottom: 12),
          child: chartPoints.isNotEmpty
              ? LineChartWidget(
                  chartPoints: chartPoints,
                  periods: periods,
                  unit: ChartUnit.number,
                  aspectRation: 1.8,
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        ...entries.reversed.toList().asMap().entries.expand((entry) {
          final index = entry.key;
          final e = entry.value;
          return [
            _TopWeightsHistoryTile(
              setIndex: e.$3,
              reps: e.$2.reps,
              exerciseLog: e.$1,
            ),
            if (index < entries.length - 1)
              Divider(
                height: 1,
                color: (Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black)
                    .withValues(alpha: 0.1),
              ),
          ];
        }),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _TopWeightsHistoryTile extends StatelessWidget {
  final int setIndex;
  final int reps;
  final ExerciseLogDto exerciseLog;

  const _TopWeightsHistoryTile({
    required this.setIndex,
    required this.reps,
    required this.exerciseLog,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final mutedColor =
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5);
    final dateText = exerciseLog.createdAt.formattedDayAndMonthAndYear();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set $setIndex',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'x$reps reps',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  dateText,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: mutedColor,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTopWeightsBreakdown extends StatelessWidget {
  const _EmptyTopWeightsBreakdown();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor =
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Text(
          'No data for this weight yet.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: mutedColor,
              ),
        ),
      ),
    );
  }
}
