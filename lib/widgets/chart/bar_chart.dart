import 'package:collection/collection.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../dtos/graph/chart_point_dto.dart';
import '../../enums/chart_unit_enum.dart';
import '../../utils/chart_utils.dart';
import '../../utils/string_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

class CustomBarChart extends StatelessWidget {
  final List<ChartPointDto> chartPoints;
  final List<String> periods;
  final List<Color>? barColors;
  final ExtraLinesData? extraLinesData;
  final ChartUnit unit;
  final bool showLeftTitles;
  final bool showTopTitles;
  final double? maxY;
  final double bottomTitlesInterval;
  final double reservedSize;

  const CustomBarChart(
      {super.key,
      required this.chartPoints,
      required this.periods,
      this.extraLinesData,
      required this.unit,
      this.maxY,
      this.showLeftTitles = true,
      this.showTopTitles = false,
      required this.bottomTitlesInterval,
      this.barColors,
      required this.reservedSize});

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return chartPoints.isNotEmpty
        ? BarChart(
            BarChartData(
              minY: 0,
              maxY: maxY,
              barTouchData: barTouchData,
              titlesData: titlesData,
              borderData: borderData,
              barGroups: barGroups(isDarkMode: isDarkMode),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                checkToShowHorizontalLine: (value) => true,
                getDrawingHorizontalLine: (value) => FlLine(
                  color: isDarkMode
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.shade200,
                  strokeWidth: 0.5,
                ),
              ),
              alignment: BarChartAlignment.spaceEvenly,
              extraLinesData: extraLinesData,
            ),
            duration: Duration.zero,
          )
        : Center(
            child: FaIcon(FontAwesomeIcons.chartSimple,
                color: isDarkMode
                    ? Theme.of(context).colors.sapphireDark
                    : Colors.grey.shade400,
                size: 120));
  }

  BarTouchData get barTouchData => BarTouchData(
        enabled: false,
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => Colors.transparent,
          tooltipPadding: EdgeInsets.zero,
          tooltipMargin: 8,
          getTooltipItem: (
            BarChartGroupData group,
            int groupIndex,
            BarChartRodData rod,
            int rodIndex,
          ) {
            return BarTooltipItem(
              rod.toY.round().toString(),
              const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            );
          },
        ),
      );

  FlTitlesData get titlesData => FlTitlesData(
        show: true,
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: bottomTitlesInterval,
            getTitlesWidget: _bottomTitleWidgets,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: showLeftTitles,
            reservedSize: reservedSize,
            getTitlesWidget: _leftTitleWidgets,
          ),
        ),
        topTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      );

  FlBorderData get borderData => FlBorderData(
        show: false,
      );

  List<BarChartGroupData> barGroups({required bool isDarkMode}) =>
      chartPoints.mapIndexed((index, point) {
        return BarChartGroupData(
          x: point.x.toInt(),
          barRods: [
            BarChartRodData(
                borderRadius: BorderRadius.circular(2),
                width: barWidth(length: chartPoints.length),
                toY: point.y.toDouble(),
                color: barColors?[index] ??
                    (isDarkMode ? Colors.white : Colors.black))
          ],
          showingTooltipIndicators: showTopTitles ? [0] : null,
        );
      }).toList();

  Widget _leftTitleWidgets(double value, TitleMeta meta) {
    final style = TextStyle(
        fontWeight: FontWeight.w500, fontSize: 9, color: Colors.grey.shade600);

    return SideTitleWidget(
      fitInside: SideTitleFitInsideData.fromTitleMeta(meta, enabled: false),
      meta: meta,
      child: Text(_weightTitle(value: value), style: style),
    );
  }

  String _weightTitle({required double value}) {
    if (unit == ChartUnit.weight) {
      return volumeInKOrM(value);
    }
    return "${value.toInt()}";
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    final modifiedDateTimes =
        periods.length == 1 ? [...periods, ...periods] : periods;
    final style = TextStyle(
        fontWeight: FontWeight.w500, fontSize: 9, color: Colors.grey.shade600);
    return SideTitleWidget(
      fitInside: SideTitleFitInsideData.disable(),
      meta: meta,
      child: value % meta.appliedInterval == 0
          ? Text(modifiedDateTimes[value.toInt()], style: style)
          : const SizedBox.shrink(),
    );
  }
}
