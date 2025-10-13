import 'package:tracker_app/dtos/set_dtos/set_dto.dart';
import '../../enums/exercise_type_enums.dart';

class RepsSetDto extends SetDto {
  final int reps;

  const RepsSetDto({
    required this.reps,
    super.checked = false,
    super.isWorkingSet = false,
    required super.dateTime,
  });

  factory RepsSetDto.defaultSet() => RepsSetDto(
        reps: 0,
        dateTime: DateTime.now(),
      );

  factory RepsSetDto.fromJson(Map<String, dynamic> json,
      {required DateTime dateTime}) {
    return RepsSetDto(
      reps: (json['reps'] as num).toInt(),
      checked: json['checked'] as bool,
      isWorkingSet: json['isWorkingSet'] as bool,
      dateTime: dateTime,
    );
  }

  @override
  ExerciseType get type => ExerciseType.bodyWeight;

  @override
  bool isEmpty() => reps == 0;

  @override
  bool isNotEmpty() => reps > 0;

  @override
  RepsSetDto copyWith({
    int? reps,
    bool? checked,
    bool? isWorkingSet,
    DateTime? dateTime,
  }) {
    return RepsSetDto(
      reps: reps ?? this.reps,
      checked: checked ?? this.checked,
      isWorkingSet: isWorkingSet ?? this.isWorkingSet,
      dateTime: dateTime ?? this.dateTime,
    );
  }

  @override
  String summary() => 'x$reps';

  @override
  Map<String, dynamic> toJson() {
    return super.toJson()
      ..addAll({
        'reps': reps,
      });
  }

  @override
  String toString() => 'RepsSetDto('
      'reps: $reps, '
      'checked: $checked, '
      'isWorkingSet: $isWorkingSet, '
      'dateTime: $dateTime'
      ')';
}
