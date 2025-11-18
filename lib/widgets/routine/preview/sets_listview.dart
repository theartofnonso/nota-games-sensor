import 'package:flutter/material.dart';
import 'package:trainware/dtos/set_dtos/duration_set_dto.dart';
import 'package:trainware/dtos/set_dtos/reps_dto.dart';
import 'package:trainware/dtos/set_dtos/weight_and_reps_dto.dart';
import 'package:trainware/extensions/duration_extension.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget.dart';
import 'package:trainware/widgets/routine/preview/set_rows/double_set_row.dart';
import 'package:trainware/widgets/routine/preview/set_rows/single_set_row.dart';

import '../../../dtos/set_dtos/set_dto.dart';
import '../../../enums/exercise_type_enums.dart';

class SetsListview extends StatelessWidget {
  final ExerciseType type;
  final List<SetDto> sets;

  const SetsListview({super.key, required this.type, required this.sets});

  @override
  Widget build(BuildContext context) {
    if (sets.isEmpty) {
      return Center(
          child: SizedBox(
        width: double.infinity,
        child: OpacityButtonWidget(
            label: "No Sets have been logged for this exercise",
            buttonColor: Colors.deepOrange,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16)),
      ));
    }

    final children = sets.asMap().entries.map((entry) {
      final set = entry.value;
      switch (set.type) {
        case ExerciseType.weights:
          final firstLabel = (set as WeightAndRepsSetDto).weight;
          final secondLabel = set.reps;
          return DoubleSetRow(first: "$firstLabel", second: "$secondLabel");
        case ExerciseType.bodyWeight:
          final label = (set as RepsSetDto).reps;
          return SingleSetRow(label: "$label");
        case ExerciseType.duration:
          final label = (set as DurationSetDto).duration.hmsDigital();
          return SingleSetRow(label: label);
      }
    }).toList();

    return Column(spacing: 8, children: children);
  }
}
