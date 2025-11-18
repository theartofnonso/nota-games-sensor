import 'package:flutter/cupertino.dart';
import 'package:trainware/enums/exercise_type_enums.dart';
import 'package:trainware/utils/general_utils.dart';

import '../../dtos/set_dtos/set_dto.dart';
import '../../dtos/set_dtos/weight_and_reps_dto.dart';
import '../../utils/sets_utils.dart';
import '../routine/preview/set_headers/double_set_header.dart';
import '../routine/preview/set_rows/double_set_row.dart';

class SetRecordWidget extends StatelessWidget {
  final ExerciseType exerciseType;
  final List<SetDto> sets;

  const SetRecordWidget(
      {super.key, required this.exerciseType, required this.sets});

  @override
  Widget build(BuildContext context) {
    final personaBestSets = personalBestSets(sets: sets);

    if (personaBestSets.isEmpty) {
      personaBestSets.add(SetDto.newType(type: exerciseType));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        DoubleSetHeader(
            firstLabel: "Reps",
            secondLabel: 'Personal Best (${weightUnit().toUpperCase()})'),
        const SizedBox(height: 8),
        ...personaBestSets.map((set) {
          final firstLabel = (set as WeightAndRepsSetDto).reps;
          final secondLabel = set.weight;
          return DoubleSetRow(first: "$firstLabel", second: "$secondLabel");
        }),
      ],
    );
  }
}
