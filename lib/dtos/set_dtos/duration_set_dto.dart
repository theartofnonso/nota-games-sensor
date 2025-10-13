import 'package:tracker_app/dtos/set_dtos/set_dto.dart';
import 'package:tracker_app/extensions/duration_extension.dart';
import '../../enums/exercise_type_enums.dart';

class DurationSetDto extends SetDto {
  final Duration duration;

  const DurationSetDto({
    required this.duration,
    super.checked = false,
    super.isWorkingSet = false,
    required super.dateTime,
  });

  factory DurationSetDto.defaultSet() => DurationSetDto(
    duration: Duration.zero,
    dateTime: DateTime.now(),
  );

  factory DurationSetDto.fromJson(Map<String, dynamic> json, {required DateTime dateTime}) {
    return DurationSetDto(
      duration: Duration(milliseconds: (json['duration'] as num).toInt()),
      checked: json['checked'] as bool,
      isWorkingSet: json['isWorkingSet'] as bool,
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
    bool? isWorkingSet,
    DateTime? dateTime,
  }) {
    return DurationSetDto(
      duration: duration ?? this.duration,
      checked: checked ?? this.checked,
      isWorkingSet: isWorkingSet ?? this.isWorkingSet,
      dateTime: dateTime ?? this.dateTime,
    );
  }

  @override
  String summary() => duration.hmsAnalog();

  @override
  Map<String, dynamic> toJson() {
    return super.toJson()
      ..addAll({
        'duration': duration.inMilliseconds,
      });
  }

  @override
  String toString() => 'DurationSetDto('
      'duration: $duration, '
      'checked: $checked, '
      'isWorkingSet: $isWorkingSet, '
      'dateTime: $dateTime'
      ')';
}