import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:trainware/dtos/graph/chart_point_dto.dart';
import 'package:trainware/extensions/duration_extension.dart';

import '../../enums/chart_unit_enum.dart';
import '../../utils/string_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

enum LineChartSide { left, right }

class LineChartWidget extends StatelessWidget {
  final List<ChartPointDto> chartPoints;
  final List<String> periods;
  final ChartUnit unit;
  final double interval;
  final double? aspectRation;
  final List<Color> colors;
  final double leftReservedSize;
  final double rightReservedSize;
  final LineChartSide lineChartSide;
  final bool hasLeftAxisTitles;
  final bool hasRightAxisTitles;
  final double? maxY;
  final Color Function(double value)? leftAxisTitlesColor;
  final Color Function(double value)? rightAxisTitlesColor;
  final bool belowBarData;
  /// Multiple series to plot (e.g. Set 1, Set 2, Set 3). When provided,
  /// [chartPoints] is ignored and each series gets its own line.
  final List<({List<ChartPointDto> points, Color? color})>? multiSeries;

  const LineChartWidget({
    super.key,
    required this.chartPoints,
    required this.periods,
    required this.unit,
    this.interval = 10,
    this.maxY,
    this.aspectRation,
    this.lineChartSide = LineChartSide.left,
    this.colors = const [],
    this.hasRightAxisTitles = false,
    this.hasLeftAxisTitles = true,
    this.leftAxisTitlesColor,
    this.rightAxisTitlesColor,
    this.leftReservedSize = 40,
    this.rightReservedSize = 40,
    this.belowBarData = true,
    this.multiSeries,
  });

  static const List<Color> _multiSeriesColors = [
    Color(0xFF4CAF50), // green
    Color(0xFF2196F3), // blue
    Color(0xFFFF9800), // orange
  ];

  bool get _hasData {
    if (multiSeries != null && multiSeries!.isNotEmpty) {
      return multiSeries!.any((s) => s.points.isNotEmpty);
    }
    return chartPoints.isNotEmpty;
  }

  List<LineChartBarData> _buildLineBars(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final defaultColor =
        isDarkMode ? Colors.white70 : Colors.grey.shade600;

    if (multiSeries != null && multiSeries!.isNotEmpty) {
      var idx = 0;
      return multiSeries!
          .where((s) => s.points.isNotEmpty)
          .map((series) {
            final color = series.color ??
                (idx < _multiSeriesColors.length
                    ? _multiSeriesColors[idx]
                    : defaultColor);
            idx++;
            return LineChartBarData(
              spots: series.points
                  .map((p) => FlSpot(p.x.toDouble(), p.y.toDouble()))
                  .toList(),
              dotData: FlDotData(show: false),
              color: color,
              belowBarData: BarAreaData(
                show: false,
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.1),
                    color.withValues(alpha: 0.0),
                  ],
                ),
              ),
              isCurved: true,
            );
          })
          .toList();
    }

    return [
      LineChartBarData(
        spots: chartPoints
            .map((p) => FlSpot(p.x.toDouble(), p.y.toDouble()))
            .toList(),
        dotData: FlDotData(show: false),
        color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
        gradient: colors.length >= 2 ? LinearGradient(colors: colors) : null,
        belowBarData: BarAreaData(
          show: belowBarData,
          gradient: LinearGradient(
            colors: [
              isDarkMode ? Colors.white : Colors.black,
              isDarkMode ? Colors.white : Colors.black,
            ]
                .map((color) =>
                    color.withValues(alpha: isDarkMode ? 0.02 : 0.05))
                .toList(),
          ),
        ),
        isCurved: true,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return _hasData
        ? Center(
            child: AspectRatio(
              aspectRatio: aspectRation ?? 1.5,
              child: LineChart(
                duration: const Duration(milliseconds: 500),
                LineChartData(
                  gridData: FlGridData(
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                        strokeWidth: 0.5, color: Colors.transparent),
                  ),
                  minY: 0,
                  maxY: maxY,
                  titlesData: FlTitlesData(
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: hasRightAxisTitles,
                        getTitlesWidget: _rightTitleWidgets,
                        reservedSize: rightReservedSize,
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        interval: interval,
                        showTitles: hasLeftAxisTitles,
                        getTitlesWidget: _leftTitleWidgets,
                        reservedSize: leftReservedSize,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: interval,
                        getTitlesWidget: periods.isNotEmpty
                            ? _bottomTitleWidgets
                            : (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: _buildLineBars(context),
                ),
              ),
            ),
          )
        : Center(
            child: FaIcon(FontAwesomeIcons.chartSimple,
                color: Theme.of(context).colors.sapphireDark, size: 120));
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta) {
    final colorFunction = leftAxisTitlesColor;
    final color = colorFunction != null ? colorFunction(value) : null;
    final style = TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 9,
        color: color ?? Colors.grey.shade600);

    return SideTitleWidget(
      fitInside: SideTitleFitInsideData.fromTitleMeta(meta, enabled: false),
      meta: meta,
      child: Text(
          lineChartSide == LineChartSide.left ? _weightTitle(value: value) : "",
          style: style),
    );
  }

  Widget _rightTitleWidgets(double value, TitleMeta meta) {
    final colorFunction = rightAxisTitlesColor;
    final color = colorFunction != null ? colorFunction(value) : null;
    final style = TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 9,
        color: color ?? Colors.grey.shade600);

    return SideTitleWidget(
      fitInside: SideTitleFitInsideData.fromTitleMeta(meta, enabled: false),
      meta: meta,
      child: Text(
          lineChartSide == LineChartSide.right
              ? _weightTitle(value: value)
              : "",
          style: style),
    );
  }

  String _weightTitle({required double value}) {
    if (unit == ChartUnit.weight || unit == ChartUnit.numberBig) {
      return volumeInKOrM(value, showLessThan1k: false);
    } else if (unit == ChartUnit.duration) {
      return Duration(milliseconds: value.toInt()).msDigital();
    }

    return "${value.toInt()}";
  }

  Widget _bottomTitleWidgets(double value, TitleMeta meta) {
    final modifiedDateTimes =
        periods.length == 1 ? [...periods, ...periods] : periods;
    final style = TextStyle(
        fontWeight: FontWeight.w500, fontSize: 7, color: Colors.grey.shade600);
    return SideTitleWidget(
      fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
      meta: meta,
      child: Text(modifiedDateTimes[value.toInt()].toUpperCase(), style: style),
    );
  }
}
