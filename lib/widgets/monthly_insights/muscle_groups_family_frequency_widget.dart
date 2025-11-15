import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../enums/muscle_group_enums.dart';
import '../chart/muscle_group_family_frequency_chart.dart';

class MuscleGroupSplitChart extends StatelessWidget {
  const MuscleGroupSplitChart(
      {super.key, required this.muscleGroup, required bool minimized, required this.title, required this.description})
      : _minimized = minimized;

  final String title;
  final String description;
  final Map<MuscleGroup, double> muscleGroup;
  final bool _minimized;

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(title.toUpperCase(), style: Theme.of(context).textTheme.titleMedium),
        const Spacer(),
        if (muscleGroup.length > 3)
          FaIcon(_minimized ? FontAwesomeIcons.angleDown : FontAwesomeIcons.angleUp, size: 16),
      ]),
      const SizedBox(height: 10),
      Text(description,
          style: isDarkMode
              ? Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70)
              : Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.black)),
      const SizedBox(height: 10),
      MuscleGroupFamilyFrequencyChart(frequencyData: muscleGroup, minimized: _minimized),
    ]);
  }
}
