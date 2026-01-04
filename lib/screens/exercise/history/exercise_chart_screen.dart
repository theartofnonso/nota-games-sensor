import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';

import 'package:provider/provider.dart';
import 'package:trainware/dtos/appsync/exercise_dto.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';
import 'package:trainware/dtos/set_dtos/weight_and_reps_dto.dart';
import 'package:trainware/extensions/datetime/datetime_extension.dart';
import 'package:trainware/extensions/duration_extension.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget.dart';
import 'package:trainware/widgets/list_tile.dart';

import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import '../../../dtos/graph/chart_point_dto.dart';
import '../../../dtos/set_dtos/set_dto.dart';
import '../../../enums/chart_unit_enum.dart';
import '../../../enums/exercise_type_enums.dart';
import '../../../utils/exercise_logs_utils.dart';
import '../../../utils/general_utils.dart';
import '../../../utils/lottie_exercise_registry.dart';
import '../../../widgets/chart/line_chart_widget.dart';
import '../../logs/routine_log_screen.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

enum SummaryType {
  weight("Heaviest Weight"),
  setVolume("Heaviest Volume (Set)"),
  bestTime("Best Time"),
  mostReps("Most Reps (Set)"),
  sessionReps("Most Reps (Session)"),
  sessionTimes("Total Time");

  const SummaryType(this.label);

  final String label;
}

class ExerciseChartScreen extends StatefulWidget {
  final (String?, double) heaviestWeight;
  final (String?, SetDto) heaviestSet;
  final (String?, Duration) longestDuration;
  final (String?, int) mostRepsSet;
  final (String?, int) mostRepsSession;
  final ExerciseDto exercise;
  final List<ExerciseLogDto> exerciseLogs;

  const ExerciseChartScreen(
      {super.key,
      required this.heaviestWeight,
      required this.heaviestSet,
      required this.longestDuration,
      required this.mostRepsSet,
      required this.mostRepsSession,
      required this.exercise,
      required this.exerciseLogs});

  @override
  State<ExerciseChartScreen> createState() => _ExerciseChartScreenState();
}

class _ExerciseChartScreenState extends State<ExerciseChartScreen> {
  List<String> _dateTimes = [];

  List<ChartPointDto> _chartPoints = [];

  late ChartUnit _chartUnit;

  late SummaryType _summaryType;
  late ExerciseType _selectedType;

  void _heaviestWeightPerLog() {
    final sets = widget.exerciseLogs
        .map((log) => heaviestWeightInSetForExerciseLog(exerciseLog: log))
        .toList();
    setState(() {
      _chartPoints = sets
          .mapIndexed((index, set) => ChartPointDto(index, (set).weight))
          .toList();
      _summaryType = SummaryType.weight;
      _chartUnit = ChartUnit.weight;
    });
  }

  void _heaviestSetVolumePerLog() {
    final values = widget.exerciseLogs
        .map((log) => heaviestVolumeForExerciseLog(exerciseLog: log))
        .toList();
    setState(() {
      _chartPoints = values
          .mapIndexed((index, value) => ChartPointDto(index, value))
          .toList();
      _summaryType = SummaryType.setVolume;
      _chartUnit = ChartUnit.weight;
    });
  }

  void _totalRepsForLog() {
    final values = widget.exerciseLogs
        .map((log) => totalRepsForExerciseLog(exerciseLog: log))
        .toList();
    setState(() {
      _chartPoints = values
          .mapIndexed((index, value) => ChartPointDto(index, value))
          .toList();
      _summaryType = SummaryType.sessionReps;
      _chartUnit = ChartUnit.weight;
    });
  }

  void _highestRepsForLog() {
    final values = widget.exerciseLogs
        .map((log) => highestRepsForExerciseLog(exerciseLog: log))
        .toList();
    setState(() {
      _chartPoints = values
          .mapIndexed((index, value) => ChartPointDto(index, value))
          .toList();
      _summaryType = SummaryType.mostReps;
      _chartUnit = ChartUnit.weight;
    });
  }

  void _longestDurationPerLog() {
    final values = widget.exerciseLogs
        .map((log) => longestDurationForExerciseLog(exerciseLog: log))
        .toList();
    setState(() {
      _chartPoints = values
          .mapIndexed(
              (index, value) => ChartPointDto(index, value.inMilliseconds))
          .toList();
      _summaryType = SummaryType.bestTime;
      _chartUnit = ChartUnit.duration;
    });
  }

  void _totalTimePerLog() {
    final values = widget.exerciseLogs
        .map((log) => totalDurationExerciseLog(exerciseLog: log))
        .toList();
    setState(() {
      _chartPoints = values
          .mapIndexed(
              (index, value) => ChartPointDto(index, value.inMilliseconds))
          .toList();
      _summaryType = SummaryType.sessionTimes;
      _chartUnit = ChartUnit.duration;
    });
  }

  void _computeChart() {
    _summaryType = switch (_selectedType) {
      ExerciseType.weights => SummaryType.weight,
      ExerciseType.bodyWeight => SummaryType.mostReps,
      ExerciseType.duration => SummaryType.bestTime,
      ExerciseType.none => SummaryType.weight,
    };

    _dateTimes = widget.exerciseLogs
        .map((log) => log.createdAt.formattedDayAndMonth())
        .toList();

    switch (_summaryType) {
      case SummaryType.weight:
        _heaviestWeightPerLog();
        break;
      case SummaryType.setVolume:
        _heaviestSetVolumePerLog();
        break;
      case SummaryType.mostReps:
        _highestRepsForLog();
        break;
      case SummaryType.sessionReps:
        _totalRepsForLog();
        break;
      case SummaryType.bestTime:
        _longestDurationPerLog();
        break;
      case SummaryType.sessionTimes:
        _totalTimePerLog();
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedType = widget.exercise.type;
    _computeChart();
  }

  void _setSelectedType(ExerciseType type) {
    if (_selectedType == type) return;
    setState(() {
      _selectedType = type;
    });
    _computeChart();
  }

  Color? _buttonColor({required SummaryType type}) {
    return _summaryType == type ? Theme.of(context).colors.vibrantAccent : null;
  }

  void _navigateTo({required String? routineLogId}) {
    if (routineLogId != null) {
      final routineLog = Provider.of<SupabaseExerciseAndRoutineController>(
              context,
              listen: false)
          .logWhereId(id: routineLogId);
      if (routineLog != null) {
        context.push(RoutineLogScreen.routeName, extra: {
          "log": routineLog,
          "showSummary": false,
          "isEditable": false,
          "showShareOnLoad": false,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    final weightUnitLabel = weightUnit();

    final exercise = widget.exercise;
    final currentType = _selectedType;
    const banColor = Color.fromRGBO(255, 255, 255, 0.4);

    return SafeArea(
      top: false,
      bottom: false,
      minimum: const EdgeInsets.only(top: 20),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AspectRatio(
                aspectRatio: 2,
                child: Center(
                  child: exercise.isSystem
                      ? FutureBuilder<String?>(
                          future:
                              LottieExerciseRegistry.lottieFor(exercise.name),
                          builder: (context, snapshot) {
                            final asset = snapshot.data;
                            if (asset != null) {
                              return Lottie.asset(
                                asset,
                                fit: BoxFit.contain,
                                repeat: true,
                              );
                            }
                            return FaIcon(
                              FontAwesomeIcons.ban,
                              size: 68,
                              color: banColor,
                            );
                          },
                        )
                      : FaIcon(
                          FontAwesomeIcons.ban,
                          size: 68,
                          color: banColor,
                        ),
                ),
              ),
              const SizedBox(height: 20),
              Divider(thickness: 1, color: Colors.white.withValues(alpha: 0.1)),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: CupertinoSlidingSegmentedControl<ExerciseType>(
                  groupValue: currentType,
                  backgroundColor: isDarkMode
                      ? Theme.of(context).colors.sapphireDark
                      : Colors.grey.shade400,
                  thumbColor: isDarkMode
                      ? Theme.of(context).colors.sapphireDark80
                      : Colors.white,
                  children: {
                    ExerciseType.weights: SizedBox(
                      width: 110,
                      child: Text(
                        "Weights (${weightUnit()})",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    ExerciseType.bodyWeight: SizedBox(
                      width: 110,
                      child: Text(
                        "Bodyweight (reps)",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    ExerciseType.duration: SizedBox(
                      width: 110,
                      child: Text(
                        "Duration (time)",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  },
                  onValueChanged: (value) {
                    if (value != null) {
                      _setSelectedType(value);
                    }
                  },
                ),
              ),
              const SizedBox(height: 30),
              if (exercise.notes.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.notes.isNotEmpty
                          ? "${exercise.notes}."
                          : "No notes",
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 14,
                          color: isDarkMode ? Colors.white70 : Colors.black,
                          height: 1.8,
                          fontWeight: FontWeight.w400),
                    ),
                    const SizedBox(height: 18),
                    const Divider(thickness: 1),
                    const SizedBox(height: 18),
                  ],
                ),
              Padding(
                padding: const EdgeInsets.only(right: 20, bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    LineChartWidget(
                      chartPoints: _chartPoints,
                      periods: _dateTimes,
                      unit: _chartUnit,
                      aspectRation: 1.8,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (widget.exerciseLogs.isNotEmpty)
                SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16.0, 0.0, 16.0, 12.0),
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      spacing: 8,
                      children: [
                        if (withWeightsOnly(type: currentType))
                          OpacityButtonWidget(
                            onPressed: _heaviestWeightPerLog,
                            label: SummaryType.weight.label,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            borderRadius: BorderRadius.circular(999),
                            buttonColor: _buttonColor(type: SummaryType.weight),
                          ),
                        if (withWeightsOnly(type: currentType))
                          OpacityButtonWidget(
                            onPressed: _heaviestSetVolumePerLog,
                            label: SummaryType.setVolume.label,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            borderRadius: BorderRadius.circular(999),
                            buttonColor:
                                _buttonColor(type: SummaryType.setVolume),
                          ),
                        if (withReps(type: currentType))
                          OpacityButtonWidget(
                            onPressed: _highestRepsForLog,
                            label: SummaryType.mostReps.label,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            borderRadius: BorderRadius.circular(999),
                            buttonColor:
                                _buttonColor(type: SummaryType.mostReps),
                          ),
                        if (withReps(type: currentType))
                          OpacityButtonWidget(
                            onPressed: _totalRepsForLog,
                            label: SummaryType.sessionReps.label,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            borderRadius: BorderRadius.circular(999),
                            buttonColor:
                                _buttonColor(type: SummaryType.sessionReps),
                          ),
                        if (withDurationOnly(type: currentType))
                          OpacityButtonWidget(
                            onPressed: _longestDurationPerLog,
                            label: SummaryType.bestTime.label,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            borderRadius: BorderRadius.circular(999),
                            buttonColor:
                                _buttonColor(type: SummaryType.bestTime),
                          ),
                        if (withDurationOnly(type: currentType))
                          OpacityButtonWidget(
                            onPressed: _totalTimePerLog,
                            label: SummaryType.sessionTimes.label,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            borderRadius: BorderRadius.circular(999),
                            buttonColor:
                                _buttonColor(type: SummaryType.sessionTimes),
                          ),
                      ],
                    )),
              if (withWeightsOnly(type: currentType))
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: _MetricListTile(
                    title: 'Heaviest Weight',
                    trailing: "${widget.heaviestWeight.$2}$weightUnitLabel",
                    subtitle: 'Heaviest weight in a set',
                    onTap: () =>
                        _navigateTo(routineLogId: widget.heaviestWeight.$1),
                    enabled: widget.exerciseLogs.isNotEmpty,
                  ),
                ),
              if (withWeightsOnly(type: currentType))
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: _MetricListTile(
                      title: 'Heaviest Set Volume',
                      trailing:
                          "${(widget.heaviestSet.$2 as WeightAndRepsSetDto).weight}$weightUnitLabel x ${(widget.heaviestSet.$2 as WeightAndRepsSetDto).reps}",
                      subtitle: 'Heaviest volume in a set',
                      onTap: () =>
                          _navigateTo(routineLogId: widget.heaviestSet.$1),
                      enabled: widget.exerciseLogs.isNotEmpty),
                ),
              if (withDurationOnly(type: currentType))
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: _MetricListTile(
                      title: 'Best Time',
                      trailing: widget.longestDuration.$2.hmsAnalog(),
                      subtitle: 'Longest time for this exercise',
                      onTap: () =>
                          _navigateTo(routineLogId: widget.longestDuration.$1),
                      enabled: widget.exerciseLogs.isNotEmpty),
                ),
              if (withReps(type: currentType))
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: _MetricListTile(
                      title: 'Most Reps (Set)',
                      trailing: "${widget.mostRepsSet.$2} reps",
                      subtitle: 'Most reps in a set',
                      onTap: () =>
                          _navigateTo(routineLogId: widget.mostRepsSet.$1),
                      enabled: widget.exerciseLogs.isNotEmpty),
                ),
              if (withReps(type: currentType))
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: _MetricListTile(
                      title: 'Most Reps (Session)',
                      trailing: "${widget.mostRepsSession.$2} reps",
                      subtitle: 'Most reps in a session',
                      onTap: () =>
                          _navigateTo(routineLogId: widget.mostRepsSession.$1),
                      enabled: widget.exerciseLogs.isNotEmpty),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricListTile extends StatelessWidget {
  const _MetricListTile(
      {required this.title,
      required this.subtitle,
      required this.trailing,
      required this.onTap,
      required this.enabled});

  final String title;
  final String subtitle;
  final String trailing;
  final Function()? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ThemeListTile(
      child: ListTile(
        onTap: enabled ? onTap : () {},
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Text(trailing),
      ),
    );
  }
}
