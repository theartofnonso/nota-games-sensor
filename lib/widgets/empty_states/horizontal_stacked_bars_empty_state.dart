import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

class HorizontalStackedBarsEmptyState extends StatelessWidget {
  const HorizontalStackedBarsEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    final colors = isDarkMode
        ? [Colors.white60, Colors.white38, Colors.white24]
        : [Colors.grey.shade400, Colors.grey.shade600, Colors.grey.shade200];

    // Define the weights and colors for the bars
    final List<Bar> bars = [3, 2, 1]
        .mapIndexed((index, value) => Bar(weight: value, color: colors[index]))
        .toList();

    // Calculate the total weight
    final int totalWeight =
        bars.fold(0, (previousValue, bar) => previousValue + bar.weight);

    // Create a list of Expanded widgets based on the weights
    final List<Widget> weightedBars = bars.map((bar) {
      return Expanded(
        flex: (bar.weight *
            10 ~/
            totalWeight), // Calculate the flex factor based on the weight
        child: Container(
          height: 10, // Fixed height for all bars
          color: bar.color,
        ),
      );
    }).toList();

    return Row(
      children: weightedBars,
    );
  }
}

// A simple class to hold the weight and color for a bar
class Bar {
  final int weight;
  final Color color;

  Bar({required this.weight, required this.color});
}
