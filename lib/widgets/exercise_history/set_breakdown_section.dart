import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

import 'package:trainware/dtos/appsync/exercise_dto.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';
import 'package:trainware/dtos/graph/chart_point_dto.dart';
import 'package:trainware/dtos/set_dtos/duration_set_dto.dart';
import 'package:trainware/dtos/set_dtos/reps_dto.dart';
import 'package:trainware/dtos/set_dtos/set_dto.dart';
import 'package:trainware/dtos/set_dtos/weight_and_reps_dto.dart';
import 'package:trainware/extensions/datetime/datetime_extension.dart';
import 'package:trainware/extensions/duration_extension.dart';
import 'package:trainware/utils/exercise_logs_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/widgets/chart/line_chart_widget.dart';

import '../../enums/chart_unit_enum.dart';
import '../../enums/exercise_type_enums.dart';

/// A section at the bottom of the Exercise Chart screen showing breakdown
/// by set index (Set 1, Set 2, Set 3). Uses iOS segmented control.
/// Only shown when there is at least one logged set.
class SetBreakdownSection extends StatefulWidget {
  final ExerciseDto exercise;
  final List<ExerciseLogDto> exerciseLogs;
  final ExerciseType selectedType;

  const SetBreakdownSection({
    super.key,
    required this.exercise,
    required this.exerciseLogs,
    required this.selectedType,
  });

  @override
  State<SetBreakdownSection> createState() => _SetBreakdownSectionState();
}

class _SetBreakdownSectionState extends State<SetBreakdownSection> {
  int _selectedSetIndex = 0;

  @override
  Widget build(BuildContext context) {
    final maxSets = maxSetCountAcrossLogs(exerciseLogs: widget.exerciseLogs);
    if (maxSets < 1) return const SizedBox.shrink();

    final setIndicesToShow = [0, 1, 2].where((i) => i < maxSets).toList();
    if (setIndicesToShow.isEmpty) return const SizedBox.shrink();

    if (!setIndicesToShow.contains(_selectedSetIndex)) {
      _selectedSetIndex = setIndicesToShow.first;
    }

    final entries = getSetIndexEntries(
        exerciseLogs: widget.exerciseLogs, setIndex: _selectedSetIndex);
    if (entries.isEmpty) {
      return _buildSection(
        setIndicesToShow: setIndicesToShow,
        child: const _EmptySetBreakdown(),
      );
    }

    return _buildSection(
      setIndicesToShow: setIndicesToShow,
      child: _SetBreakdownContent(
        exercise: widget.exercise,
        entries: entries,
        selectedType: widget.selectedType,
        selectedSetIndex: _selectedSetIndex,
      ),
    );
  }

  Widget _buildSection({
    required List<int> setIndicesToShow,
    required Widget child,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 28),
        Divider(thickness: 1, color: Colors.white.withValues(alpha: 0.1)),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'By Set',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CupertinoSlidingSegmentedControl<int>(
            groupValue: _selectedSetIndex,
            backgroundColor: isDark
                ? Theme.of(context).colors.sapphireDark
                : Colors.grey.shade400,
            thumbColor:
                isDark ? Theme.of(context).colors.sapphireDark80 : Colors.white,
            children: {
              for (final idx in setIndicesToShow)
                idx: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                  child: Text(
                    'Set ${idx + 1}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
            },
            onValueChanged: (value) {
              if (value != null) {
                setState(() => _selectedSetIndex = value);
              }
            },
          ),
        ),
        const SizedBox(height: 20),
        child,
      ],
    );
  }
}

class _SetBreakdownContent extends StatelessWidget {
  final ExerciseDto exercise;
  final List<(ExerciseLogDto, SetDto)> entries;
  final ExerciseType selectedType;
  final int selectedSetIndex;

  const _SetBreakdownContent({
    required this.exercise,
    required this.entries,
    required this.selectedType,
    required this.selectedSetIndex,
  });

  @override
  Widget build(BuildContext context) {
    final chartData = _buildChartData();
    final periods =
        entries.map((e) => e.$1.createdAt.formattedDayAndMonth()).toList();
    final chartPoints = chartData
        .asMap()
        .entries
        .map((e) => ChartPointDto(e.key, e.value))
        .toList();
    final chartUnit = _chartUnit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 20, bottom: 12),
          child: chartPoints.isNotEmpty
              ? LineChartWidget(
                  chartPoints: chartPoints,
                  periods: periods,
                  unit: chartUnit,
                  aspectRation: 1.8,
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 16),
        ...entries.reversed.toList().asMap().entries.expand((entry) {
          final index = entry.key;
          final e = entry.value;
          return [
            _SetHistoryTile(
              setIndex: selectedSetIndex + 1,
              exerciseLog: e.$1,
              set: e.$2,
              selectedType: selectedType,
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

  List<double> _buildChartData() {
    return entries.map((e) => _numericValue(e.$2)).toList();
  }

  double _numericValue(SetDto set) {
    return switch (set) {
      WeightAndRepsSetDto() => (set as WeightAndRepsSetDto).weight,
      RepsSetDto() => (set as RepsSetDto).reps.toDouble(),
      DurationSetDto() =>
        (set as DurationSetDto).duration.inMilliseconds.toDouble(),
      _ => 0.0,
    };
  }

  ChartUnit get _chartUnit {
    return switch (selectedType) {
      ExerciseType.weights => ChartUnit.weight,
      ExerciseType.bodyWeight => ChartUnit.number,
      ExerciseType.duration => ChartUnit.duration,
      ExerciseType.none => ChartUnit.weight,
    };
  }
}

class _SetHistoryTile extends StatelessWidget {
  final int setIndex;
  final ExerciseLogDto exerciseLog;
  final SetDto set;
  final ExerciseType selectedType;

  const _SetHistoryTile({
    required this.setIndex,
    required this.exerciseLog,
    required this.set,
    required this.selectedType,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : Colors.black87;
    final mutedColor =
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5);

    final valueText = _valueText;
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
                Text(valueText,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600, color: textColor)),
                const SizedBox(height: 2),
                Text(dateText,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: mutedColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String get _valueText {
    return switch (set) {
      WeightAndRepsSetDto() => (set as WeightAndRepsSetDto).summary(),
      RepsSetDto() => '${(set as RepsSetDto).reps} reps',
      DurationSetDto() => (set as DurationSetDto).duration.hmsAnalog(),
      _ => set.summary(),
    };
  }
}

class _EmptySetBreakdown extends StatelessWidget {
  const _EmptySetBreakdown();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final mutedColor =
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Center(
        child: Text(
          'No data for this set yet.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: mutedColor,
              ),
        ),
      ),
    );
  }
}
