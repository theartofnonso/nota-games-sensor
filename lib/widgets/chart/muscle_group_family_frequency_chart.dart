import 'package:flutter/material.dart';

import '../../enums/muscle_group_enums.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

class MuscleGroupFamilyFrequencyChart extends StatelessWidget {
  final Map<MuscleGroup, double> frequencyData;
  final bool minimized;
  final bool forceDarkMode;

  const MuscleGroupFamilyFrequencyChart(
      {super.key, required this.frequencyData, this.minimized = false, this.forceDarkMode = false});

  @override
  Widget build(BuildContext context) {
    return _HorizontalBarChart(
      frequencyData: frequencyData,
      minimized: minimized,
      forceDarkMode: forceDarkMode,
    );
  }
}

class _HorizontalBarChart extends StatelessWidget {
  final bool minimized;
  final Map<MuscleGroup, double> frequencyData;
  final bool forceDarkMode;

  const _HorizontalBarChart({required this.frequencyData, required this.minimized, required this.forceDarkMode});

  @override
  Widget build(BuildContext context) {
    final entries = (minimized ? frequencyData.entries.take(3) : frequencyData.entries).toList();

    final children = entries
        .map((entry) => _LinearBar(muscleGroupFamily: entry.key, frequency: entry.value, forceDarkMode: forceDarkMode))
        .toList();

    return Column(spacing: 8, children: children);
  }
}

class _LinearBar extends StatelessWidget {
  final MuscleGroup muscleGroupFamily;
  final double frequency;
  final bool forceDarkMode;

  const _LinearBar({required this.muscleGroupFamily, required this.frequency, required this.forceDarkMode});

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.only(top: 10, right: 6, left: 8, bottom: 10),
      decoration: BoxDecoration(
        color: isDarkMode || forceDarkMode ? Colors.black12 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                LinearProgressIndicator(
                  value: frequency,
                  backgroundColor: isDarkMode || forceDarkMode ? Theme.of(context).colors.sapphireDark80 : Colors.grey.shade400,
                  color: isDarkMode || forceDarkMode ? Colors.white : Colors.black,
                  minHeight: 25,
                  borderRadius: BorderRadius.circular(3.0), // Border r
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: Text(muscleGroupFamily.name.toUpperCase(),
                      style: isDarkMode || forceDarkMode
                          ? Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.black, fontWeight: FontWeight.w700)
                          : Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
                )
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 35,
            child: Text("${(frequency * 100).round()}%",
                style: isDarkMode || forceDarkMode
                    ? Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w700)
                    : Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.black, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
