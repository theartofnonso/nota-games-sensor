
import 'package:collection/collection.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tracker_app/dtos/graph/chart_point_dto.dart';
import 'package:tracker_app/enums/muscle_group_enums.dart';
import 'package:tracker_app/shared_prefs.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

import 'package:tracker_app/controllers/supabase_exercise_and_routine_controller.dart';
import '../../dtos/appsync/routine_plan_dto.dart';
import '../../dtos/appsync/routine_template_dto.dart';
import '../../dtos/viewmodels/routine_log_arguments.dart';
import '../../dtos/viewmodels/routine_template_arguments.dart';
import '../../enums/chart_unit_enum.dart';
import '../../enums/posthog_analytics_event.dart';
import '../../enums/routine_editor_type_enums.dart';
import '../../enums/routine_preview_type_enum.dart';
import '../../urls.dart';
import '../../utils/data_trend_utils.dart';
import '../../utils/dialog_utils.dart';
import '../../utils/exercise_logs_utils.dart';
import '../../utils/general_utils.dart';
import '../../utils/navigation_utils.dart';
import '../../utils/routine_utils.dart';
import '../../utils/string_utils.dart';
import '../../widgets/backgrounds/trkr_loading_screen.dart';
import '../../widgets/calendar/calendar.dart';
import '../../widgets/calendar/calendar_logs.dart';
import '../../widgets/chart/line_chart_widget.dart';
import '../../widgets/chip_one.dart';
import '../../widgets/empty_states/not_found.dart';
import '../../widgets/icons/custom_icon.dart';
import '../../widgets/information_containers/information_container.dart';
import '../../widgets/monthly_insights/muscle_groups_family_frequency_widget.dart';
import '../../widgets/routine/preview/exercise_log_listview.dart';
import '../../widgets/routine/preview/plan_picker.dart';

enum _OriginalNewValues {
  originalValues(
      name: "Original Values",
      description:
          "Showing values from the last time this template was saved or updated."),
  newValues(
      name: "Recent Values",
      description: "Showing values from your last logged session.");

  const _OriginalNewValues({required this.name, required this.description});

  final String name;
  final String description;
}

class RoutineTemplateScreen extends StatefulWidget {
  static const routeName = '/routine_template_screen';

  final String id;

  const RoutineTemplateScreen({super.key, required this.id});

  @override
  State<RoutineTemplateScreen> createState() => _RoutineTemplateScreenState();
}

class _RoutineTemplateScreenState extends State<RoutineTemplateScreen> {
  RoutineTemplateDto? _template;

  bool _loading = false;

  RecoveryResult? _selectedMuscleAndRecovery;

  _OriginalNewValues _originalNewValues = _OriginalNewValues.newValues;

  DateTime? _selectedCalendarDate;

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    if (_loading) return TRKRLoadingScreen(action: _hideLoadingScreen);

    final exerciseAndRoutineController =
        Provider.of<SupabaseExerciseAndRoutineController>(context, listen: false);

    if (exerciseAndRoutineController.errorMessage.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        showSnackbar(
            context: context,
            message: exerciseAndRoutineController.errorMessage);
      });
    }

    final template = _template;

    if (template == null) return const NotFound();

    final plan = exerciseAndRoutineController.planWhere(id: template.planId);

    final muscleGroupFamilyFrequencies =
        muscleGroupFrequency(exerciseLogs: template.exerciseTemplates);

    final allLogsForTemplate = exerciseAndRoutineController
        .whereLogsWithTemplateId(templateId: template.id)
        .map((log) => routineWithLoggedExercises(log: log))
        .toList();

    final allLoggedVolumesForTemplate =
        allLogsForTemplate.map((log) => log.volume).toList();

    final avgVolume = allLoggedVolumesForTemplate.isNotEmpty
        ? allLoggedVolumesForTemplate.average
        : 0.0;

    final volumeChartPoints = allLoggedVolumesForTemplate
        .mapIndexed((index, volume) => ChartPointDto(index, volume))
        .toList();

    final trendSummary =
        _analyzeWeeklyTrends(volumes: allLoggedVolumesForTemplate);

    final muscleGroups = template.exerciseTemplates
        .map((exerciseTemplate) => exerciseTemplate.exercise.primaryMuscleGroup)
        .toSet()
        .map((muscleGroup) => muscleGroup)
        .toList();

    final listOfMuscleAndRecovery = muscleGroups.map((muscleGroup) {
      final pastExerciseLogs =
          (Provider.of<SupabaseExerciseAndRoutineController>(context, listen: false)
                  .exerciseLogsByMuscleGroup[muscleGroup] ??
              []);
      final lastExerciseLog =
          pastExerciseLogs.isNotEmpty ? pastExerciseLogs.last : null;
      final lastTrainingTime = lastExerciseLog?.createdAt;
      final recovery = lastTrainingTime != null
          ? _calculateMuscleRecovery(
              lastTrainingTime: lastTrainingTime, muscleGroup: muscleGroup)
          : RecoveryResult(
              recoveryPercentage: 0,
              muscleGroup: muscleGroup,
              lastTrainingTime: DateTime.now(),
              description:
                  "No recovery data available for $muscleGroup. Please log a $muscleGroup session to see updated recovery.");
      return recovery;
    });

    final selectedMuscleAndRecovery = _selectedMuscleAndRecovery ??
        (listOfMuscleAndRecovery.isNotEmpty
            ? listOfMuscleAndRecovery.first
            : null);

    final muscleGroupsIllustrations =
        listOfMuscleAndRecovery.map((muscleAndRecovery) {
      final muscleGroup = muscleAndRecovery.muscleGroup;
      final recovery = muscleAndRecovery.recoveryPercentage;

      return Badge(
        backgroundColor: lowToHighIntensityColor(recovery),
        alignment: Alignment.topRight,
        smallSize: 12,
        isLabelVisible: muscleGroup == selectedMuscleAndRecovery?.muscleGroup,
        child: GestureDetector(
          onTap: () {
            setState(() {
              _selectedMuscleAndRecovery = muscleAndRecovery;
            });
          },
          child: Stack(alignment: Alignment.center, children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  value: recovery,
                  strokeWidth: 6,
                  backgroundColor:
                      isDarkMode ? Colors.black12 : Colors.grey.shade400,
                  strokeCap: StrokeCap.round,
                  valueColor: AlwaysStoppedAnimation<Color>(
                      lowToHighIntensityColor(recovery)),
                ),
              ),
            ),
            Opacity(
              opacity: recovery == 0 ? 0.3 : 1.0,
              child: Image.asset(
                recoveryMuscleIllustration(
                    recoveryPercentage: recovery, muscleGroup: muscleGroup),
                fit: BoxFit.contain,
                height: 50, // Adjust the height as needed
              ),
            )
          ]),
        ),
      );
    }).toList();

    final exerciseTemplates = _originalNewValues == _OriginalNewValues.newValues
        ? template.exerciseTemplates.map((exerciseTemplate) {
            final pastSets =
                exerciseAndRoutineController.whereRecentSetsForExercise(
                    exercise: exerciseTemplate.exercise);
            final uncheckedSets =
                pastSets.map((set) => set.copyWith(checked: false)).toList();
            return exerciseTemplate.copyWith(sets: uncheckedSets);
          }).toList()
        : template.exerciseTemplates;

    return Scaffold(
        floatingActionButton: FloatingActionButton(
            heroTag: UniqueKey,
            onPressed: () => template.owner == SharedPrefs().userId
                ? _launchRoutineLogEditor(muscleGroups: muscleGroups)
                : _createTemplate(),
            child: template.owner == SharedPrefs().userId
                ? const FaIcon(FontAwesomeIcons.play, size: 24)
                : const FaIcon(FontAwesomeIcons.download)),
        appBar: AppBar(
          backgroundColor: appBarBackgroundColor(context: context),
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const FaIcon(FontAwesomeIcons.arrowLeftLong, size: 28),
            onPressed: context.pop,
          ),
          actions: [
            template.owner == SharedPrefs().userId
                ? IconButton(
                    onPressed: () => _showMenuBottomSheet(planDto: plan),
                    icon: FaIcon(Icons.more_vert_rounded))
                : const SizedBox.shrink()
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: themeGradient(context: context),
          ),
          child: SafeArea(
            bottom: false,
            minimum: const EdgeInsets.only(top: 10.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 20,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Column(
                      spacing: 20,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 2,
                          children: [
                            Text(template.name,
                                style: TextStyle(
                                    fontSize: 20,
                                    height: 1.5,
                                    fontWeight: FontWeight.w900)),
                            if (plan != null)
                              Text(
                                "In ${plan.name}",
                                style: TextStyle(
                                    fontSize: 14,
                                    color: isDarkMode
                                        ? Colors.white70
                                        : Colors.black,
                                    fontWeight: FontWeight.w400),
                              )
                          ],
                        ),
                        Column(
                          spacing: 12,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ChipOne(
                                label:
                                    "${template.exerciseTemplates.length} ${pluralize(word: "Exercise", count: template.exerciseTemplates.length)}",
                                child: CustomIcon(
                                    FontAwesomeIcons.personWalking,
                                    color: Theme.of(context).colors.vibrantAccent)),
                            Text(
                              template.notes.isNotEmpty
                                  ? "${template.notes}."
                                  : "No notes",
                              style: TextStyle(
                                  fontSize: 14,
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.black,
                                  height: 1.8,
                                  fontWeight: FontWeight.w400),
                            )
                          ],
                        ),
                        Calendar(
                          onSelectDate: (date) =>
                              _onSelectCalendarDateTime(date: date),
                          logs: allLogsForTemplate,
                        ),
                        CalendarLogs(
                            dateTime: _selectedCalendarDate ?? DateTime.now()),
                        MuscleGroupSplitChart(
                            title: "Muscle Groups Split",
                            description:
                                "Here's a breakdown of the muscle groups in your ${template.name} workout plan.",
                            muscleGroup: muscleGroupFamilyFrequencies,
                            minimized: false),
                      ],
                    ),
                  ),
                  if (template.owner == SharedPrefs().userId)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            spacing: 10,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 10,
                                children: [
                                  trendSummary.trend == Trend.none
                                      ? const SizedBox.shrink()
                                      : getTrendIcon(trend: trendSummary.trend),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          text: volumeInKOrM(avgVolume),
                                          style: Theme.of(context)
                                              .textTheme
                                              .headlineSmall,
                                          children: [
                                            TextSpan(
                                              text: " ",
                                            ),
                                            TextSpan(
                                              text: weightUnit().toUpperCase(),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium,
                                            ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        "Session AVERAGE".toUpperCase(),
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                      ),
                                    ],
                                  )
                                ],
                              ),
                              Text(trendSummary.summary,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.w400,
                                          color: isDarkMode
                                              ? Colors.white70
                                              : Colors.black)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const SizedBox(height: 16),
                              LineChartWidget(
                                chartPoints: volumeChartPoints,
                                periods: [],
                                unit: ChartUnit.weight,
                                aspectRation: 4.5,
                                lineChartSide: LineChartSide.right,
                                rightReservedSize: 20,
                                hasLeftAxisTitles: false,
                                belowBarData: false,
                                hasRightAxisTitles: false,
                              ),
                            ],
                          ),
                          Text(
                              "Here’s a volume trend of your ${template.name} training over the last ${allLogsForTemplate.length} ${pluralize(word: "session", count: allLogsForTemplate.length)}.",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      fontWeight: FontWeight.w400,
                                      color: isDarkMode
                                          ? Colors.white70
                                          : Colors.black)),
                          const SizedBox(height: 12),
                          InformationContainer(
                            leadingIcon: FaIcon(FontAwesomeIcons.weightHanging),
                            title: "Training Volume",
                            color: isDarkMode
                                ? Theme.of(context).colors.sapphireDark80
                                : Colors.grey.shade200,
                            description:
                                "Volume is the total amount of work done, often calculated as sets × reps × weight. Higher volume increases muscle size (hypertrophy).",
                          ),
                        ],
                      ),
                    ),
                  if (template.owner == SharedPrefs().userId)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10.0),
                      child: Container(
                        decoration: BoxDecoration(
                            color: isDarkMode
                                ? Theme.of(context).colors.sapphireDark80
                                : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(5)),
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 20,
                          children: [
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Muscle Recovery".toUpperCase(),
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium),
                                  const SizedBox(height: 10),
                                  Text(
                                      "Delayed Onset Muscle Soreness (DOMS) refers to the muscle pain or stiffness experienced after intense physical activity. It typically develops 24 to 48 hours after exercise and can last for several days.",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              fontWeight: FontWeight.w400,
                                              color: isDarkMode
                                                  ? Colors.white70
                                                  : Colors.black)),
                                ],
                              ),
                            ),
                            if (listOfMuscleAndRecovery.isNotEmpty)
                              Column(
                                spacing: 10,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          spacing: 20,
                                          children: [
                                            SizedBox(width: 2),
                                            ...muscleGroupsIllustrations,
                                            SizedBox(width: 2),
                                          ])),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10.0),
                                    child: Text(
                                        selectedMuscleAndRecovery
                                                ?.description ??
                                            "",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                                fontWeight: FontWeight.w400,
                                                color: isDarkMode
                                                    ? Colors.white
                                                    : Colors.black)),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      spacing: 30,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          spacing: 6,
                          children: [
                            CupertinoSlidingSegmentedControl<
                                _OriginalNewValues>(
                              backgroundColor: isDarkMode
                                  ? Theme.of(context).colors.sapphireDark
                                  : Colors.grey.shade200,
                              thumbColor:
                                  isDarkMode ? Theme.of(context).colors.sapphireDark80 : Colors.white,
                              groupValue: _originalNewValues,
                              children: {
                                _OriginalNewValues.originalValues: SizedBox(
                                    width: 100,
                                    child: Text(
                                        _OriginalNewValues.originalValues.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                        textAlign: TextAlign.center)),
                                _OriginalNewValues.newValues: SizedBox(
                                    width: 100,
                                    child: Text(
                                        _OriginalNewValues.newValues.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall,
                                        textAlign: TextAlign.center)),
                              },
                              onValueChanged: (_OriginalNewValues? value) {
                                if (value != null) {
                                  setState(() {
                                    _originalNewValues = value;
                                  });
                                }
                              },
                            ),
                            Text(_originalNewValues.description,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                        fontWeight: FontWeight.w400,
                                        color: isDarkMode
                                            ? Colors.white70
                                            : Colors.black)),
                          ],
                        ),
                        ExerciseLogListView(
                          exerciseLogs: exerciseLogsToViewModels(
                              exerciseLogs: exerciseTemplates),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
        ));
  }

  void _showLoadingScreen() {
    setState(() {
      _loading = true;
    });
  }

  void _hideLoadingScreen() {
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _onSelectCalendarDateTime({required DateTime date}) {
    setState(() {
      _selectedCalendarDate = date;
    });
  }

  void _deleteRoutine({required RoutineTemplateDto template}) async {
    try {
      await Provider.of<SupabaseExerciseAndRoutineController>(context, listen: false)
          .removeTemplate(template: template);
      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showSnackbar(context: context, message: "Unable to remove workout");
      }
    } finally {
      _toggleLoadingState();
    }
  }

  void _toggleLoadingState() {
    setState(() {
      _loading = !_loading;
    });
  }

  void _navigateToRoutineTemplateEditor() async {
    final template = _template;
    if (template != null) {
      final copyOfTemplate = template.copyWith();
      final arguments = RoutineTemplateArguments(
          template: copyOfTemplate, planId: copyOfTemplate.planId);
      final updatedTemplate = await navigateToRoutineTemplateEditor(
          context: context, arguments: arguments);
      if (updatedTemplate != null) {
        setState(() {
          _template = updatedTemplate;
        });
      }
    }
  }

  void _launchRoutineLogEditor({required List<MuscleGroup> muscleGroups}) {
    final template = _template;
    if (template != null) {
      final log = template.toLog();
      final arguments =
          RoutineLogArguments(log: log, editorMode: RoutineEditorMode.log);
      navigateToRoutineLogEditor(context: context, arguments: arguments);
    }
  }

  void _createTemplate({bool copy = false}) async {
    final template = _template;
    if (template != null) {
      _showLoadingScreen();

      try {
        final exercises = template.exerciseTemplates.map((exerciseLog) {
          final uncheckedSets = exerciseLog.sets
              .map((set) => set.copyWith(checked: false))
              .toList();
          return exerciseLog.copyWith(sets: uncheckedSets);
        }).toList();
        final templateToBeCreated = RoutineTemplateDto(
            id: "",
            name: copy ? "Copy of ${template.name}" : template.name,
            notes: template.notes,
            exerciseTemplates: exercises,
            owner: "",
            planId: template.planId,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now());

        final createdTemplate = await Provider.of<SupabaseExerciseAndRoutineController>(
                context,
                listen: false)
            .saveTemplate(templateDto: templateToBeCreated);
        if (mounted) {
          if (createdTemplate != null) {
            navigateToRoutineTemplatePreview(
                context: context, template: createdTemplate);
          }
        }
      } catch (_) {
        if (mounted) {
          showSnackbar(
              context: context,
              message: "Oops, we are unable to create your template");
        }
      } finally {
        _hideLoadingScreen();
      }
    }
  }

  void _loadData() {
    final exerciseAndRoutineController =
        Provider.of<SupabaseExerciseAndRoutineController>(context, listen: false);
    _template = exerciseAndRoutineController.templateWhere(id: widget.id);
    
    // TODO: Implement shared workout loading via Supabase public access
    // For now, only load from user's own data
    if (_template == null) {
      setState(() {
        _loading = false;
      });
    }
  }

  void _showShareBottomSheet() {
    final template = _template;

    if (template != null) {
      final workoutLink = "$shareableRoutineUrl/${template.id}";
      final workoutText = copyRoutineAsText(
          routineType: RoutinePreviewType.template,
          name: template.name,
          notes: template.notes,
          exerciseLogs: template.exerciseTemplates);

      displayBottomSheet(
          context: context,
          isScrollControlled: true,
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const FaIcon(
                FontAwesomeIcons.link,
                size: 18,
              ),
              horizontalTitleGap: 10,
              title: Text(
                "Copy as Link",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      overflow: TextOverflow.ellipsis,
                    ),
                maxLines: 1,
              ),
              subtitle: Text(workoutLink),
              onTap: () {
                Posthog().capture(
                    eventName: PostHogAnalyticsEvent
                        .shareRoutineTemplateAsLink.displayName);
                HapticFeedback.heavyImpact();
                final data = ClipboardData(text: workoutLink);
                Clipboard.setData(data).then((_) {
                  if (mounted) {
                    Navigator.of(context).pop();
                    showSnackbar(
                        context: context, message: "Workout link copied");
                  }
                });
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const FaIcon(
                FontAwesomeIcons.copy,
                size: 18,
              ),
              horizontalTitleGap: 6,
              title: Text("Copy as Text",
                  style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text("${template.name}..."),
              onTap: () {
                Posthog().capture(
                    eventName: PostHogAnalyticsEvent
                        .shareRoutineTemplateAsText.displayName);
                HapticFeedback.heavyImpact();
                final data = ClipboardData(text: workoutText);
                Clipboard.setData(data).then((_) {
                  if (mounted) {
                    Navigator.of(context).pop();
                    showSnackbar(context: context, message: "Workout copied");
                  }
                });
              },
            ),
          ]));
    }
  }

  void _showMenuBottomSheet({required RoutinePlanDto? planDto}) {
    displayBottomSheet(
        context: context,
        isScrollControlled: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const FaIcon(
              FontAwesomeIcons.penToSquare,
              size: 18,
            ),
            horizontalTitleGap: 10,
            title: Text("Edit", style: Theme.of(context).textTheme.bodyLarge),
            onTap: () {
              Navigator.of(context).pop();
              _navigateToRoutineTemplateEditor();
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const FaIcon(
              FontAwesomeIcons.copy,
              size: 18,
            ),
            horizontalTitleGap: 6,
            title: Text("Copy", style: Theme.of(context).textTheme.bodyLarge),
            onTap: () {
              Navigator.of(context).pop();
              _createTemplate(copy: true);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const FaIcon(
              FontAwesomeIcons.share,
              size: 18,
            ),
            horizontalTitleGap: 6,
            title: Text("Share", style: Theme.of(context).textTheme.bodyLarge),
            onTap: () {
              Navigator.of(context).pop();
              _showShareBottomSheet();
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const FaIcon(
              FontAwesomeIcons.solidSquarePlus,
              size: 18,
            ),
            horizontalTitleGap: 6,
            title: Text("Move to another plan",
                style: Theme.of(context).textTheme.bodyLarge),
            onTap: () {
              Navigator.of(context).pop();
              _showPlanPicker();
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const FaIcon(
              FontAwesomeIcons.trash,
              size: 16,
              color: Colors.redAccent,
            ),
            horizontalTitleGap: 6,
            title: Text("Delete",
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: Colors.red)),
            onTap: () {
              Navigator.of(context).pop();

              final template = _template;

              if (template != null) {
                showBottomSheetWithMultiActions(
                    context: context,
                    title: "Delete workout?",
                    description: planDto != null
                        ? "Are you sure you want to delete this workout and remove it from ${planDto.name}?"
                        : "Are you sure you want to delete this workout?",
                    leftAction: Navigator.of(context).pop,
                    rightAction: () {
                      context.pop();
                      _toggleLoadingState();
                      _deleteRoutine(template: template);
                    },
                    leftActionLabel: 'Cancel',
                    rightActionLabel: 'Delete',
                    isRightActionDestructive: true);
              }
            },
          )
        ]));
  }

  void _showPlanPicker() {
    final template = _template;

    final exerciseAndRoutineController =
        Provider.of<SupabaseExerciseAndRoutineController>(context, listen: false);
    final plans = exerciseAndRoutineController.plans;

    if (template != null) {
      displayBottomSheet(
        context: context,
        child: PlanPicker(
          title: "Move ${template.name} to . . .",
          plans: plans,
          onSelect: (selectedPlan) async {
            Navigator.of(context).pop();

            final templateProvider = Provider.of<SupabaseExerciseAndRoutineController>(
                context,
                listen: false);

            final updatedRoutineTemplate =
                template.copyWith(planId: selectedPlan.id);

            await templateProvider.updateTemplate(
                template: updatedRoutineTemplate);

            if (mounted) {
              showSnackbar(
                  context: context,
                  message: "Add ${template.name} to ${selectedPlan.name}");
            }
          },
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  TrendSummary _analyzeWeeklyTrends({required List<double> volumes}) {
    // 1. If there's no data at all, return immediately
    if (volumes.isEmpty) {
      return TrendSummary(
        trend: Trend.none,
        average: 0,
        summary:
            "No training data available yet. Log some sessions to start tracking your progress!",
      );
    }

    // 2. If there's only one logged volume, we can't do sublist(0, volumes.length - 1) safely,
    // so just return a summary for that single volume.
    if (volumes.length == 1) {
      final singleVolume = volumes.first;
      return TrendSummary(
        trend: Trend.none,
        average: singleVolume,
        summary:
            "You've logged your first session. Great job! Keep logging more data to see trends over time.",
      );
    }

    // From here on, volumes has at least 2 items,
    // so sublist and reduce are safe.
    final previousVolumes = volumes.sublist(0, volumes.length - 1);
    final averageOfPrevious =
        previousVolumes.reduce((a, b) => a + b) / previousVolumes.length;
    final lastWeekVolume = volumes.last;

    // If the last session’s volume is 0, treat it as a special case.
    if (lastWeekVolume == 0) {
      return TrendSummary(
        trend: Trend.none,
        average: averageOfPrevious,
        summary:
            "No training data available for this session. Log some workouts to continue tracking your progress!",
      );
    }

    // Calculate difference and percentage change
    final difference = lastWeekVolume - averageOfPrevious;
    final differenceIsZero = difference == 0;
    final bool averageIsZero = averageOfPrevious == 0;
    final double percentageChange =
        averageIsZero ? 100.0 : (difference / averageOfPrevious) * 100;

    // Decide the trend based on a threshold
    const threshold = 5; // e.g., ±5%
    late final Trend trend;

    if (percentageChange > threshold) {
      trend = Trend.up;
    } else if (percentageChange < -threshold) {
      trend = Trend.down;
    } else {
      trend = Trend.stable;
    }

    final variation = "${percentageChange.abs().toStringAsFixed(1)}%";

    switch (trend) {
      case Trend.up:
        return TrendSummary(
          trend: Trend.up,
          average: averageOfPrevious,
          summary:
              "🌟🌟 Last session's volume is $variation higher than your average. "
              "Awesome job building momentum!",
        );

      case Trend.down:
        return TrendSummary(
          trend: Trend.down,
          average: averageOfPrevious,
          summary:
              "📉 Last session's volume is $variation lower than your average. "
              "Consider extra rest, checking your technique, or planning a deload.",
        );

      case Trend.stable:
        final summary = differenceIsZero
            ? "🌟 You've matched your session average! Stay consistent to see long-term progress."
            : "🔄 Your volume changed by about $variation compared to your session average. "
                "A great chance to refine your form and maintain consistency.";
        return TrendSummary(
          trend: Trend.stable,
          average: averageOfPrevious,
          summary: summary,
        );

      case Trend.none:
        // Fallback, though we typically won't reach this if we've assigned up/down/stable
        return TrendSummary(
          trend: Trend.none,
          average: averageOfPrevious,
          summary: "🤔 Unable to identify trends",
        );
    }
  }
}

class RecoveryResult {
  final double recoveryPercentage;
  final MuscleGroup muscleGroup;
  final DateTime lastTrainingTime;
  final String description;

  RecoveryResult(
      {required this.recoveryPercentage,
      required this.muscleGroup,
      required this.lastTrainingTime,
      required this.description});

  @override
  String toString() {
    return 'RecoveryResult{recoveryPercentage: $recoveryPercentage, muscleGroup: $muscleGroup, lastTrainingTime: $lastTrainingTime, desciption: $description}';
  }
}

/// Calculates muscle recovery percentage based on time since last training.
/// - 0% means no recovery (extremely fresh DOMS).
/// - 100% means fully recovered.
/// - If more than 7 days have passed and soreness remains, we flag overtraining.
///
/// You can adjust these time thresholds or percentages as needed.
RecoveryResult _calculateMuscleRecovery(
    {required DateTime lastTrainingTime, required MuscleGroup muscleGroup}) {
  // Calculate hours since last training.
  final hoursSinceTraining =
      DateTime.now().difference(lastTrainingTime).inHours;

  // A simple piecewise approach to approximate "percent recovered."
  // Tweak as needed for your app’s logic.
  double recoveryPercentage;

  String description;

  if (hoursSinceTraining < 24) {
    // Within first 24 hours after training — DOMS just starting
    recoveryPercentage = -0.01;
    description =
        "Your $muscleGroup was just trained. Be sure to allow enough recovery time—DOMS can appear within the next day or two";
  } else if (hoursSinceTraining < 48) {
    // 24–48 hours: muscle soreness typically peaks
    // We assume minimal recovery, e.g. up to ~30%
    final ratio = (hoursSinceTraining - 24) / 24;
    recoveryPercentage = 0.3 * ratio;
    description =
        "Your $muscleGroup is only ${(recoveryPercentage * 100).floor()}% recovered. DOMS is likely high. "
        "It's best to rest or do very light activity today.";
  } else if (hoursSinceTraining < 72) {
    // 48–72 hours: soreness usually starts to fade
    // Move recovery from ~30% to ~70%
    final ratio = (hoursSinceTraining - 48) / 24;
    recoveryPercentage = 0.3 + 0.4 * ratio; // ~30% -> 70%
    description =
        "Your $muscleGroup is about ${(recoveryPercentage * 100).floor()}% recovered. Moderate soreness may still be present. "
        "Light to moderate training can be considered, but monitor how you feel.";
  } else if (hoursSinceTraining < 96) {
    // 72–96 hours: typically nearing full recovery
    // Move recovery from ~70% to ~90%
    final ratio = (hoursSinceTraining - 72) / 24;
    recoveryPercentage = 0.7 + 0.2 * ratio; // ~70% -> 90%
    description =
        "Your $muscleGroup is ${(recoveryPercentage * 100).floor()}% recovered. Soreness should be minimal. "
        "Feel free to train, but keep an eye on any lingering tightness.";
  } else if (hoursSinceTraining < 168) {
    // 4–7 days: often fully recovered or very close
    // We treat this range as ~90% -> 100% recovery
    final ratio = (hoursSinceTraining - 96) / 72;
    recoveryPercentage = 0.9 + 0.1 * ratio; // ~90% -> 100%
    description =
        "Your $muscleGroup is ${(recoveryPercentage * 100).floor()}% recovered. Soreness should be minimal. "
        "Feel free to train, but keep an eye on any lingering tightness.";
  } else {
    // 7+ days of soreness likely indicates overtraining or incomplete recovery
    // You could set this to 100% and rely on [isOvertrained] for the warning,
    // or set it to 0% to indicate "inconsistent with normal recovery."
    // Below, we assume 100% physically, but isOvertrained = true means possible problem.
    recoveryPercentage = 1.0;
    description =
        "Your $muscleGroup is fully recovered at 100%. You're good to train!";
  }

  // Clamp between 0.0 and 1.0 in case of minor rounding
  recoveryPercentage = recoveryPercentage.clamp(0.0, 1.0);

  return RecoveryResult(
      recoveryPercentage: recoveryPercentage,
      muscleGroup: muscleGroup,
      lastTrainingTime: lastTrainingTime,
      description: description);
}
