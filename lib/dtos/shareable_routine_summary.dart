import 'package:trainware/dtos/appsync/routine_log_dto.dart';
import 'package:trainware/extensions/duration_extension.dart';
import 'package:trainware/utils/personal_bests_utils.dart';

/// Minimal payload used to populate shareable workout summary assets.
class ShareableRoutineSummary {
  final String routineName;
  final Duration duration;
  final int exerciseCount;
  final int setCount;
  final List<PersonalBest> personalBests;

  /// Pre-formatted values used directly by templates.
  final String durationLabel;

  const ShareableRoutineSummary({
    required this.routineName,
    required this.duration,
    required this.exerciseCount,
    required this.setCount,
    required this.personalBests,
    required this.durationLabel,
  });

  factory ShareableRoutineSummary.fromRoutineLog(
    RoutineLogDto log, {
    List<PersonalBest>? personalBests,
  }) {
    final duration = log.duration();
    final exercises = log.exerciseLogs.length;
    final sets = log.exerciseLogs.fold<int>(
      0,
      (previousValue, element) => previousValue + element.sets.length,
    );
    return ShareableRoutineSummary(
      routineName: log.name,
      duration: duration,
      exerciseCount: exercises,
      setCount: sets,
      personalBests: personalBests ?? const [],
      durationLabel: duration.hmsDigital(),
    );
  }
}
