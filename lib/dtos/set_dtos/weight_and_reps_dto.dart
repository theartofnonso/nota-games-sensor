import 'package:tracker_app/dtos/set_dtos/set_dto.dart';
import 'package:tracker_app/utils/general_utils.dart';

import '../../enums/exercise_type_enums.dart';

class WeightAndRepsSetDto extends SetDto {
  final double weight;
  final int reps;

  const WeightAndRepsSetDto({
    required this.weight,
    required this.reps,
    super.checked = false,
    super.isWorkingSet = false,
    required super.dateTime,
  });

  factory WeightAndRepsSetDto.defaultSet() => WeightAndRepsSetDto(
        weight: 0,
        reps: 0,
        dateTime: DateTime.now(),
      );

  factory WeightAndRepsSetDto.fromJson(Map<String, dynamic> json,
      {required DateTime dateTime}) {
    return WeightAndRepsSetDto(
      weight: (json['weight'] as num).toDouble(),
      reps: (json['reps'] as num).toInt(),
      checked: json['isChecked'] as bool,
      isWorkingSet: json['isWorkingSet'] as bool,
      dateTime: dateTime,
    );
  }

  @override
  ExerciseType get type => ExerciseType.weights;

  @override
  bool isEmpty() => weight == 0 && reps == 0;

  @override
  bool isNotEmpty() => weight > 0 && reps > 0;

  @override
  WeightAndRepsSetDto copyWith({
    bool? checked,
    bool? isWorkingSet,
    DateTime? dateTime,
    double? weight,
    int? reps,
  }) {
    return WeightAndRepsSetDto(
      weight: weight ?? this.weight,
      reps: reps ?? this.reps,
      checked: checked ?? this.checked,
      isWorkingSet: isWorkingSet ?? this.isWorkingSet,
      dateTime: dateTime ?? this.dateTime,
    );
  }

  @override
  String summary() => '$weight${weightUnit()} x $reps reps';

  @override
  Map<String, dynamic> toJson() {
    return super.toJson()
      ..addAll({
        'weight': weight,
        'reps': reps,
      });
  }

  double volume() {
    final convertedWeight = weightWithConversion(value: weight);
    return (convertedWeight * reps);
  }
}
