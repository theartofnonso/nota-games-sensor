import 'package:trainware/dtos/set_dtos/set_dto.dart';
import 'package:trainware/extensions/duration_extension.dart';
import '../../enums/exercise_type_enums.dart';

class DurationSetDto extends SetDto {
  final Duration duration;

  const DurationSetDto({
    required this.duration,
    super.checked = false,
    required super.dateTime,
  });

  factory DurationSetDto.defaultSet() => DurationSetDto(
        duration: Duration.zero,
        dateTime: DateTime.now(),
      );

  factory DurationSetDto.fromJson(Map<String, dynamic> json,
      {required DateTime dateTime}) {
    return DurationSetDto(
      duration: Duration(milliseconds: (json['duration'] as num).toInt()),
      checked: json['checked'] as bool,
      dateTime: dateTime,
    );
  }

  @override
  ExerciseType get type => ExerciseType.duration;

  @override
  bool isEmpty() => duration == Duration.zero;

  @override
  bool isNotEmpty() => duration > Duration.zero;

  @override
  DurationSetDto copyWith({
    Duration? duration,
    bool? checked,
    DateTime? dateTime,
  }) {
    return DurationSetDto(
      duration: duration ?? this.duration,
      checked: checked ?? this.checked,
      dateTime: dateTime ?? this.dateTime,
    );
  }

  @override
  String summary() => duration.hmsAnalog();

  @override
  Map<String, dynamic> toJson() => super.toJson();

  @override
  String toString() => 'DurationSetDto('
      'duration: $duration, '
      'checked: $checked, '
      'dateTime: $dateTime'
      ')';
}
