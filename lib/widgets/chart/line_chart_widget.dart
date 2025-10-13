import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:tracker_app/dtos/graph/chart_point_dto.dart';
import 'package:tracker_app/extensions/duration_extension.dart';

import '../../colors.dart';
import '../../enums/chart_unit_enum.dart';
import '../../utils/string_utils.dart';

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
  const LineChartWidget(
      {super.key,
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
      this.leftReservedSize = 40, this.rightReservedSize = 40, this.belowBarData = true});

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return chartPoints.isNotEmpty
        ? Center(
            child: AspectRatio(
              aspectRatio: aspectRation ?? 1.5,
              child: LineChart(
                  duration: Duration(milliseconds: 500),
                  LineChartData(
                      gridData: FlGridData(
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (_) =>
                              FlLine(strokeWidth: 0.5, color: Colors.transparent)),
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
                            getTitlesWidget: periods.isNotEmpty ? _bottomTitleWidgets : (_, __) => SizedBox.shrink(),
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: false,
                      ),
                      lineBarsData: [
                        LineChartBarData(
                            spots: chartPoints.map((point) {
                              return FlSpot(point.x.toDouble(), point.y.toDouble());
                            }).toList(),
                            dotData: FlDotData(show: false),
                            color: isDarkMode ? Colors.white70 : Colors.grey.shade600,
                            gradient: colors.length >= 2 ? LinearGradient(colors: colors) : null,
                            belowBarData: BarAreaData(
                              show: belowBarData,
                              gradient: LinearGradient(
                                colors: [
                                  isDarkMode ? Colors.white : Colors.black,
                                  isDarkMode ? Colors.white : Colors.black
                                ].map((color) => color.withValues(alpha: isDarkMode ? 0.02 : 0.05)).toList(),
                              ),
                            ),
                            isCurved: true)
                      ])),
            ),
          )
        : const Center(child: FaIcon(FontAwesomeIcons.chartSimple, color: sapphireDark, size: 120));
  }

  Widget _leftTitleWidgets(double value, TitleMeta meta) {
    final colorFunction = leftAxisTitlesColor;
    final color = colorFunction != null ? colorFunction(value) : null;
    final style = TextStyle(fontWeight: FontWeight.w500, fontSize: 9, color: color ?? Colors.grey.shade600);

    return SideTitleWidget(
      fitInside: SideTitleFitInsideData.fromTitleMeta(meta, enabled: false),
      meta: meta,
      child: Text(lineChartSide == LineChartSide.left ? _weightTitle(value: value) : "", style: style),
    );
  }

  Widget _rightTitleWidgets(double value, TitleMeta meta) {
    final colorFunction = rightAxisTitlesColor;
    final color = colorFunction != null ? colorFunction(value) : null;
    final style = TextStyle(fontWeight: FontWeight.w500, fontSize: 9, color: color ?? Colors.grey.shade600);

    return SideTitleWidget(
      fitInside: SideTitleFitInsideData.fromTitleMeta(meta, enabled: false),
      meta: meta,
      child: Text(lineChartSide == LineChartSide.right ? _weightTitle(value: value) : "", style: style),
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
    final modifiedDateTimes = periods.length == 1 ? [...periods, ...periods] : periods;
    final style = TextStyle(fontWeight: FontWeight.w500, fontSize: 7, color: Colors.grey.shade600);
    return SideTitleWidget(
      fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
      meta: meta,
      child: Text(modifiedDateTimes[value.toInt()].toUpperCase(), style: style),
    );
  }
}