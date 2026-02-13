import 'package:trainware/dtos/set_dtos/reps_dto.dart';
import 'package:trainware/dtos/set_dtos/weight_and_reps_dto.dart';

import '../../enums/exercise_type_enums.dart';
import 'duration_set_dto.dart';

abstract class SetDto {
  final bool _isChecked;
  final DateTime _dateTime;

  const SetDto({bool checked = false, required dateTime})
      : _isChecked = checked,
        _dateTime = dateTime;

  bool get checked => _isChecked;

  DateTime get dateTime => _dateTime;

  ExerciseType get type;

  bool isEmpty();

  bool isNotEmpty();

  SetDto copyWith({bool? checked});

  String summary();

  Map<String, dynamic> toJson() {
    if (this is WeightAndRepsSetDto) {
      final weightAndRepSet = this as WeightAndRepsSetDto;
      return {
        "weight": weightAndRepSet.weight,
        "reps": weightAndRepSet.reps,
        "checked": _isChecked,
      };
    } else if (this is RepsSetDto) {
      final repSet = this as RepsSetDto;
      return {"reps": repSet.reps, "checked": _isChecked};
    } else {
      final durationSet = this as DurationSetDto;
      return {
        "duration": durationSet.duration.inMilliseconds,
        "checked": _isChecked,
      };
    }
  }

  factory SetDto.fromJson(Map<String, dynamic> json,
      {required ExerciseType exerciseType, required DateTime datetime}) {
    final checked = json["checked"] as bool? ?? false;

    double weight(Map<String, dynamic> j) {
      if (j["weight"] != null) return (j["weight"] as num).toDouble();
      if (j["value1"] != null) return (j["value1"] as num).toDouble();
      return 0;
    }

    int reps(Map<String, dynamic> j) {
      if (j["reps"] != null) return (j["reps"] as num).toInt();
      if (j["value2"] != null) return (j["value2"] as num).toInt();
      return 0;
    }

    int durationMs(Map<String, dynamic> j) {
      if (j["duration"] != null) return (j["duration"] as num).toInt();
      if (j["value2"] != null) return (j["value2"] as num).toInt();
      return 0;
    }

    return switch (exerciseType) {
      ExerciseType.weights => WeightAndRepsSetDto(
          weight: weight(json),
          reps: reps(json),
          checked: checked,
          dateTime: datetime),
      ExerciseType.bodyWeight =>
        RepsSetDto(reps: reps(json), checked: checked, dateTime: datetime),
      ExerciseType.duration => DurationSetDto(
          duration: Duration(milliseconds: durationMs(json)),
          checked: checked,
          dateTime: datetime),
      ExerciseType.none =>
        throw const FormatException('Exercise type must be selected for sets'),
    };
  }

  factory SetDto.newType({required ExerciseType type}) {
    return switch (type) {
      ExerciseType.weights => WeightAndRepsSetDto.defaultSet(),
      ExerciseType.bodyWeight => RepsSetDto.defaultSet(),
      ExerciseType.duration => DurationSetDto.defaultSet(),
      ExerciseType.none =>
        throw const FormatException('Exercise type must be selected for sets'),
    };
  }
}
