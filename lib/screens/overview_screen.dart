import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:provider/provider.dart';
import 'package:tracker_app/colors.dart';
import 'package:tracker_app/extensions/datetime/datetime_extension.dart';
import 'package:tracker_app/screens/editors/past_routine_log_editor_screen.dart';
import 'package:tracker_app/utils/dialog_utils.dart';
import 'package:tracker_app/widgets/routine/preview/routine_plan_grid_item.dart';

import '../controllers/exercise_and_routine_controller.dart';
import '../dtos/appsync/routine_log_dto.dart';
import '../dtos/appsync/routine_template_dto.dart';
import '../dtos/appsync/routine_plan_dto.dart';
import '../utils/date_utils.dart';
import '../utils/general_utils.dart';
import '../utils/navigation_utils.dart';
import '../widgets/backgrounds/trkr_loading_screen.dart';
import '../widgets/calendar/calendar.dart';
import '../widgets/calendar/calendar_logs.dart';
import '../widgets/monitors/full_animated_gauge.dart';
import '../widgets/monthly_insights/log_streak_chart.dart';
import '../widgets/monthly_insights/volume_chart.dart';

enum TrainingAndVolume {
  training,
  volume;
}

class OverviewScreen extends StatefulWidget {
  static const routeName = '/overview_screen';

  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  bool _loading = false;

  DateTime? _selectedCalendarDate;

  DateTimeRange? _calendarDateTimeRange;

  TrainingAndVolume _trainingAndVolume = TrainingAndVolume.training;

  String _predictTemplate({required List<RoutineLogDto> logs}) {
    if (logs.isEmpty) {
      return "";
    }

    final currentWeekday = DateTime.now().weekday;
    final sameWeekdayLogs =
        logs.where((log) => log.createdAt.weekday == currentWeekday).toList();

    final logsToConsider = sameWeekdayLogs.isNotEmpty ? sameWeekdayLogs : logs;

    final counts = <String, int>{};
    final latestDates = <String, DateTime>{};

    for (final log in logsToConsider) {
      final templateId = log.templateId;
      counts[templateId] = (counts[templateId] ?? 0) + 1;

      final currentLatest = latestDates[templateId];
      if (currentLatest == null || log.createdAt.isAfter(currentLatest)) {
        latestDates[templateId] = log.createdAt;
      }
    }

    final maxCount =
        counts.values.fold(0, (max, count) => count > max ? count : max);
    final candidates = counts.entries
        .where((entry) => entry.value == maxCount)
        .map((entry) => entry.key)
        .toList();

    if (candidates.length == 1) {
      return candidates.first;
    }

    // Resolve tie by selecting the most recent date
    String selectedId = candidates.first;
    DateTime latestDate = latestDates[selectedId]!;

    for (final id in candidates.skip(1)) {
      final date = latestDates[id]!;
      if (date.isAfter(latestDate)) {
        selectedId = id;
        latestDate = date;
      }
    }

    return selectedId;
  }

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    if (_loading) return TRKRLoadingScreen(action: _hideLoadingScreen);

    /// Be notified of changes
    final exerciseAndRoutineController =
        Provider.of<ExerciseAndRoutineController>(context, listen: true);

    final logsForCurrentDay = exerciseAndRoutineController
        .whereLogsIsSameDay(dateTime: DateTime.now().withoutTime())
        .toList();

    final templates = exerciseAndRoutineController.templates;

    final lastQuarter = lastQuarterDateTimeRange();

    final logsInLastQuarter =
        exerciseAndRoutineController.whereLogsIsWithinRange(range: lastQuarter);

    final predictedTemplateId = _predictTemplate(logs: logsInLastQuarter);

    final predictedTemplate = templates
        .firstWhereOrNull((template) => template.id == predictedTemplateId);

    final hasPredictedTemplateBeenLogged = logsForCurrentDay.firstWhereOrNull(
            (log) => log.templateId == predictedTemplate?.id) !=
        null;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(children: [
          Calendar(
              onSelectDate: _onSelectCalendarDateTime,
              onMonthChanged: _onMonthChanged),
          const SizedBox(
            height: 10,
          ),
          CalendarLogs(dateTime: _selectedCalendarDate ?? DateTime.now()),
          StaggeredGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              StaggeredGridTile.count(
                crossAxisCellCount: 1,
                mainAxisCellCount: 1,
                child: predictedTemplate != null
                    ? _ScheduledTitle(
                        schedule: predictedTemplate,
                        isLogged: hasPredictedTemplateBeenLogged)
                    : const _NoScheduledTitle(),
              ),
              StaggeredGridTile.count(
                crossAxisCellCount: 1,
                mainAxisCellCount: 1,
                child: _LogStreakTile(
                    dateTimeRange:
                        _calendarDateTimeRange ?? thisMonthDateRange()),
              ),
              StaggeredGridTile.count(
                crossAxisCellCount: 1,
                mainAxisCellCount: 1,
                child: _YearlyStreakTile(),
              ),
              StaggeredGridTile.count(
                crossAxisCellCount: 1,
                mainAxisCellCount: 2,
                child: Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: isDarkMode
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(5)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      switch (_trainingAndVolume) {
                        TrainingAndVolume.training => LogStreakChart(),
                        TrainingAndVolume.volume => VolumeChart(),
                      },
                      const Spacer(),
                      CupertinoSlidingSegmentedControl<TrainingAndVolume>(
                        backgroundColor:
                            isDarkMode ? sapphireDark : Colors.grey.shade400,
                        thumbColor: isDarkMode ? sapphireDark80 : Colors.white,
                        groupValue: _trainingAndVolume,
                        children: {
                          TrainingAndVolume.training: SizedBox(
                              width: 80,
                              child: Text("Training",
                                  style: Theme.of(context).textTheme.bodySmall,
                                  textAlign: TextAlign.center)),
                          TrainingAndVolume.volume: SizedBox(
                              width: 80,
                              child: Text("Volume",
                                  style: Theme.of(context).textTheme.bodySmall,
                                  textAlign: TextAlign.center)),
                        },
                        onValueChanged: (TrainingAndVolume? value) {
                          if (value != null) {
                            setState(() {
                              _trainingAndVolume = value;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              StaggeredGridTile.count(
                crossAxisCellCount: 1,
                mainAxisCellCount: 1,
                child: RoutinePlanGridItemWidget(
                    plan: RoutinePlanDto.defaultPlan, radius: 5),
              ),
              StaggeredGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                children: [
                  StaggeredGridTile.count(
                    crossAxisCellCount: 1,
                    mainAxisCellCount: 1,
                    child: GestureDetector(
                      onTap: () => navigateToRoutineHome(context: context),
                      child: _RoutinePlansHomeTile(),
                    ),
                  ),
                  StaggeredGridTile.count(
                    crossAxisCellCount: 1,
                    mainAxisCellCount: 1,
                    child: GestureDetector(
                      onTap: _showNewBottomSheet,
                      child: _AddTile(),
                    ),
                  ),
                  StaggeredGridTile.count(
                    crossAxisCellCount: 1,
                    mainAxisCellCount: 1,
                    child: GestureDetector(
                      onTap: () => navigateToSettings(context: context),
                      child: _SettingsTile(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ]),
      ),
    );
  }

  void _hideLoadingScreen() {
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _showNewBottomSheet() {
    displayBottomSheet(
        context: context,
        child: Column(children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const FaIcon(FontAwesomeIcons.play, size: 18),
            horizontalTitleGap: 6,
            title: Text("Log new session",
                style: Theme.of(context).textTheme.bodyLarge),
            onTap: () {
              Navigator.of(context).pop();
              logEmptyRoutine(context: context);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const FaIcon(FontAwesomeIcons.clockRotateLeft, size: 18),
            horizontalTitleGap: 6,
            title: Text("Log past session",
                style: Theme.of(context).textTheme.bodyLarge),
            onTap: () {
              Navigator.of(context).pop();
              showDatetimeRangePicker(
                  context: context,
                  onChangedDateTimeRange: (DateTimeRange datetimeRange) {
                    Navigator.of(context).pop();
                    final logName =
                        "${timeOfDay(datetime: datetimeRange.start)} Session";
                    final log = RoutineLogDto(
                        id: "",
                        templateId: '',
                        name: logName,
                        exerciseLogs: [],
                        notes: "",
                        startTime: datetimeRange.start,
                        endTime: datetimeRange.end,
                        owner: "",
                        createdAt: datetimeRange.start,
                        updatedAt: datetimeRange.end);
                    navigateWithSlideTransition(
                        context: context,
                        child: PastRoutineLogEditorScreen(log: log));
                  });
            },
          ),
        ]));
  }

  void _onSelectCalendarDateTime(DateTime date) {
    setState(() {
      _selectedCalendarDate = date;
    });
  }

  void _onMonthChanged(DateTimeRange dateRange) {
    setState(() {
      _calendarDateTimeRange = dateRange;
    });
  }
}

class _LogStreakTile extends StatelessWidget {
  final DateTimeRange dateTimeRange;

  const _LogStreakTile({required this.dateTimeRange});

  @override
  Widget build(BuildContext context) {
    final exerciseAndRoutineController =
        Provider.of<ExerciseAndRoutineController>(context, listen: false);

    final routineLogs = exerciseAndRoutineController.whereLogsIsWithinRange(
        range: dateTimeRange);

    final routineLogsByDay =
        groupBy(routineLogs, (log) => log.createdAt.withoutTime().day);

    final monthlyProgress = routineLogsByDay.length;

    final color = lowToHighIntensityColor(monthlyProgress / 12);

    return GestureDetector(
      onTap: () {
        showBottomSheetWithNoAction(
            context: context,
            title: "Log Streak",
            description:
                "Streak is the number of days you engage in strength training each month, with an ideal target of 12 days.");
      },
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(5)),
        child: FullAnimatedGauge(
          value: monthlyProgress,
          min: 0,
          max: 12,
          label: "Days",
        ),
      ),
    );
  }
}

class _YearlyStreakTile extends StatelessWidget {
  const _YearlyStreakTile();

  @override
  Widget build(BuildContext context) {
    final exerciseAndRoutineController =
        Provider.of<ExerciseAndRoutineController>(context, listen: false);

    final lastYearRange = yearToDateTimeRange(datetime: DateTime.now());
    final logsForTheYear = exerciseAndRoutineController.whereLogsIsWithinRange(
        range: lastYearRange);

    final yearlyProgress = logsForTheYear.length;
    final year = DateTime.now().year;

    return GestureDetector(
      onTap: () {
        showBottomSheetWithNoAction(
            context: context,
            title: "Yearly Streak",
            description:
                "Your yearly streak tracks your total training sessions in $year. Hit 12 sessions a month to stay on track for 144 in a year.");
      },
      child: Container(
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: vibrantGreen.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(5)),
        child: FullAnimatedGauge(
          value: yearlyProgress,
          min: 0,
          max: 144,
          label: "Sessions",
        ),
      ),
    );
  }
}

class _NoScheduledTitle extends StatelessWidget {
  const _NoScheduledTitle();

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(5)),
      child: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
        Text("Keep training to see future schedules",
            style: TextStyle(
                fontSize: 18, height: 1.5, fontWeight: FontWeight.w600)),
        const Spacer(),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Container(
              width: 25,
              height: 25,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.black.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Center(
                child: FaIcon(
                  FontAwesomeIcons.calendarDay,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            )
          ],
        ),
      ]),
    );
  }
}

class _ScheduledTitle extends StatelessWidget {
  const _ScheduledTitle({required this.schedule, required this.isLogged});

  final RoutineTemplateDto schedule;

  final bool isLogged;

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return GestureDetector(
      onTap: () => navigateToRoutineTemplatePreview(
          context: context, template: schedule),
      child: isLogged
          ? Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: isDarkMode
                      ? vibrantGreen.withValues(alpha: 0.1)
                      : vibrantGreen,
                  borderRadius: BorderRadius.circular(5)),
              child:
                  Column(mainAxisAlignment: MainAxisAlignment.start, children: [
                Text("${schedule.name} has been completed. Great job!",
                    style: TextStyle(
                        fontSize: 18,
                        height: 1.5,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 25,
                      height: 25,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: vibrantGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Center(
                        child: FaIcon(
                          FontAwesomeIcons.check,
                          color: vibrantGreen,
                          size: 14,
                        ),
                      ),
                    )
                  ],
                ),
              ]),
            )
          : Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: isDarkMode
                      ? vibrantGreen.withValues(alpha: 0.1)
                      : vibrantGreen,
                  borderRadius: BorderRadius.circular(5)),
              child:
                  Column(mainAxisAlignment: MainAxisAlignment.start, children: [
                Text("${schedule.name} is scheduled today!",
                    style: TextStyle(
                        fontSize: 18,
                        height: 1.5,
                        fontWeight: FontWeight.w600)),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: 25,
                      height: 25,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: isDarkMode
                            ? vibrantGreen.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Center(
                        child: FaIcon(
                          FontAwesomeIcons.calendarDay,
                          color: isDarkMode ? vibrantGreen : Colors.white,
                          size: 14,
                        ),
                      ),
                    )
                  ],
                ),
              ]),
            ),
    );
  }
}

class _RoutinePlansHomeTile extends StatelessWidget {
  const _RoutinePlansHomeTile();

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.purple.withValues(alpha: 0.1)
              : Colors.purple.shade300,
          borderRadius: BorderRadius.circular(5)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        FaIcon(
          FontAwesomeIcons.solidFolderOpen,
          size: 32,
          color: Colors.white,
        ),
      ]),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile();

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
          color:
              isDarkMode ? Colors.yellow.withValues(alpha: 0.1) : Colors.yellow,
          borderRadius: BorderRadius.circular(5)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        FaIcon(
          FontAwesomeIcons.plus,
          size: 32,
          color: Colors.white,
        ),
      ]),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile();

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: isDarkMode
              ? Colors.grey.withValues(alpha: 0.1)
              : Colors.grey.shade300,
          borderRadius: BorderRadius.circular(5)),
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        FaIcon(
          FontAwesomeIcons.gear,
          size: 32,
          color: Colors.white,
        ),
      ]),
    );
  }
}
