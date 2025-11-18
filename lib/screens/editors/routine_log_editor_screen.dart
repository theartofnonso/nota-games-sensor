import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import 'package:trainware/controllers/exercise_log_controller.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';
import 'package:trainware/utils/dialog_utils.dart';
import 'package:trainware/utils/exercise_logs_utils.dart';
import 'package:trainware/utils/routine_editors_utils.dart';
import 'package:trainware/widgets/routine/editors/exercise_log_grid_item.dart';

import 'package:trainware/utils/theme/color_extensions.dart';
import '../../controllers/supabase_exercise_and_routine_controller.dart';
import '../../dtos/appsync/exercise_dto.dart';
import '../../enums/routine_editor_type_enums.dart';
import '../../utils/general_utils.dart';
import '../../utils/notifications_utils.dart';
import '../../utils/routine_utils.dart';
import '../../widgets/buttons/opacity_button_widget_two.dart';
import '../../widgets/empty_states/no_list_empty_state.dart';

class RoutineLogEditorScreen extends StatefulWidget {
  static const routeName = '/routine-log-editor';

  final RoutineLogDto log;
  final RoutineEditorMode mode;
  final bool cached;

  const RoutineLogEditorScreen(
      {super.key, required this.log, required this.mode, this.cached = false});

  @override
  State<RoutineLogEditorScreen> createState() => _RoutineLogEditorScreenState();
}

class _RoutineLogEditorScreenState extends State<RoutineLogEditorScreen>
    with WidgetsBindingObserver {
  void _selectExercisesInLibrary() async {
    final controller =
        Provider.of<ExerciseLogController>(context, listen: false);
    final excludeExercises =
        controller.exerciseLogs.map((procedure) => procedure.exercise).toList();

    showExercisesInLibrary(
        context: context,
        exercisesToExclude: excludeExercises,
        onSelected: (List<ExerciseDto> selectedExercises) {
          final onlyExercise = selectedExercises.first;
          final pastSets = Provider.of<SupabaseExerciseAndRoutineController>(
                  context,
                  listen: false)
              .whereRecentSetsForExercise(exercise: onlyExercise);
          controller.addExerciseLog(exercise: onlyExercise, pastSets: pastSets);
        });
  }

  void _showSuperSetExercisePicker({required ExerciseLogDto firstExerciseLog}) {
    final controller =
        Provider.of<ExerciseLogController>(context, listen: false);
    final otherExercises = whereOtherExerciseLogsExcept(
        exerciseLog: firstExerciseLog, others: controller.exerciseLogs);
    showSuperSetExercisePicker(
        context: context,
        firstExerciseLog: firstExerciseLog,
        otherExerciseLogs: otherExercises,
        onSelected: (secondExerciseLog) {
          _closeDialog();
          final id = superSetId(
              firstExerciseLog: firstExerciseLog,
              secondExerciseLog: secondExerciseLog);
          controller.superSetExerciseLogs(
              firstExerciseLogId: firstExerciseLog.id,
              secondExerciseLogId: secondExerciseLog.id,
              superSetId: id);
        },
        selectExercisesInLibrary: () {
          _closeDialog();
          _selectExercisesInLibrary();
        });
  }

  void _showReplaceExercisePicker({required ExerciseLogDto oldExerciseLog}) {
    final controller =
        Provider.of<ExerciseLogController>(context, listen: false);
    final excludeExercises =
        controller.exerciseLogs.map((procedure) => procedure.exercise).toList();

    showExercisesInLibrary(
        context: context,
        exercisesToExclude: excludeExercises,
        onSelected: (List<ExerciseDto> selectedExercises) {
          final pastSets = Provider.of<SupabaseExerciseAndRoutineController>(
                  context,
                  listen: false)
              .whereRecentSetsForExercise(exercise: selectedExercises.first);
          controller.replaceExerciseLog(
              oldExerciseId: oldExerciseLog.id,
              newExercise: selectedExercises.first,
              pastSets: pastSets);
        });
  }

  RoutineLogDto _routineLog() {
    final exerciseLogController =
        Provider.of<ExerciseLogController>(context, listen: false);

    final exerciseLogs = exerciseLogController.exerciseLogs;

    final routineLog = widget.log.copyWith(exerciseLogs: exerciseLogs);

    return routineLog;
  }

  Future<void> _doCreateRoutineLog() async {
    final routineLogToBeCreated =
        _routineLog().copyWith(endTime: DateTime.now());

    if (mounted) {
      final createdRoutineLog =
          await Provider.of<SupabaseExerciseAndRoutineController>(context,
                  listen: false)
              .saveLog(logDto: routineLogToBeCreated);

      // Check mounted again after async operation
      if (!mounted) return;

      // Clear cache ONLY if save succeeded
      if (createdRoutineLog != null) {
        Provider.of<ExerciseLogController>(context, listen: false).onClear();
      }

      // Always exit regardless of save success/failure
      _navigateBack(routineLog: createdRoutineLog);
    }
  }

  Future<void> _doUpdateRoutineLog() async {
    final routineLogToBeUpdated = _routineLog();

    final success = await Provider.of<SupabaseExerciseAndRoutineController>(
            context,
            listen: false)
        .updateLog(log: routineLogToBeUpdated);

    // Clear cache ONLY if update succeeded
    if (success && mounted) {
      Provider.of<ExerciseLogController>(context, listen: false).onClear();
    }

    // Always exit regardless of update success/failure
    if (mounted) {
      _navigateBack(routineLog: routineLogToBeUpdated);
    }
  }

  bool _isRoutinePartiallyComplete() {
    final exerciseLogController =
        Provider.of<ExerciseLogController>(context, listen: false);
    final exerciseLogs = exerciseLogController.exerciseLogs;
    return exerciseLogs.isNotEmpty &&
        exerciseLogs.any(
            (log) => log.sets.any((set) => set.isNotEmpty() && set.checked));
  }

  void _discardLog() {
    showBottomSheetWithMultiActions(
        context: context,
        title: "Discard session?",
        description: "Do you want to discard this session",
        leftAction: _closeDialog,
        rightAction: () {
          _closeDialog();
          // Clear cache when user explicitly discards
          Provider.of<ExerciseLogController>(context, listen: false).onClear();
          _navigateBack();
        },
        leftActionLabel: 'Cancel',
        rightActionLabel: 'Discard',
        isRightActionDestructive: true);
  }

  void _saveLog() {
    final isRoutinePartiallyComplete = _isRoutinePartiallyComplete();
    if (isRoutinePartiallyComplete) {
      showBottomSheetWithMultiActions(
          context: context,
          title: 'Running Session',
          description: "Do you want to end session?",
          leftAction: Navigator.of(context).pop,
          rightAction: () {
            _closeDialog();
            _doCreateRoutineLog();
          },
          leftActionLabel: 'Cancel',
          rightActionLabel: 'End',
          rightActionColor: Theme.of(context).colors.vibrantAccent);
    } else {
      showBottomSheetWithNoAction(
          context: context,
          description: "Complete some sets!",
          title: 'Running Session');
    }
  }

  void _updateLog() {
    final isRoutinePartiallyComplete = _isRoutinePartiallyComplete();
    if (isRoutinePartiallyComplete) {
      _closeDialog();
      _doUpdateRoutineLog();
    } else {
      showBottomSheetWithNoAction(
          context: context,
          description: "Complete some sets!",
          title: 'Update Workout');
    }
  }

  void _closeDialog() {
    Navigator.of(context).pop();
  }

  void _navigateBack({RoutineLogDto? routineLog}) async {
    context.pop(routineLog);
  }

  @override
  Widget build(BuildContext context) {
    final exerciseLogController =
        Provider.of<ExerciseLogController>(context, listen: false);

    final exerciseLogs = context
        .select((ExerciseLogController controller) => controller.exerciseLogs);

    final log = widget.log;

    final children = exerciseLogs.map((exerciseLog) {
      return ExerciseLogGridItemWidget(
        editorType: widget.mode,
        exerciseLogDto: exerciseLog,
        superSet: whereOtherExerciseInSuperSet(
            firstExercise: exerciseLog, exercises: exerciseLogs),
        onRemoveSuperSet: (String superSetId) {
          exerciseLogController.removeSuperSet(
              superSetId: exerciseLog.superSetId);
        },
        onRemoveLog: () {
          exerciseLogController.removeExerciseLog(logId: exerciseLog.id);
        },
        onSuperSet: () =>
            _showSuperSetExercisePicker(firstExerciseLog: exerciseLog),
        onReplaceLog: () =>
            _showReplaceExercisePicker(oldExerciseLog: exerciseLog),
      );
    }).toList();

    return PopScope(
        canPop: false,
        child: Scaffold(
            appBar: AppBar(
              backgroundColor: appBarBackgroundColor(context: context),
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              leading: IconButton(
                  icon: const FaIcon(FontAwesomeIcons.arrowLeftLong),
                  onPressed: _discardLog),
              title: Text(
                log.name,
              ),
              actions: [
                IconButton(
                    key: const Key('select_exercises_in_library_btn'),
                    onPressed: _selectExercisesInLibrary,
                    icon: const FaIcon(FontAwesomeIcons.circlePlus)),
              ],
            ),
            body: Container(
              decoration: BoxDecoration(
                gradient: themeGradient(context: context),
              ),
              child: SafeArea(
                minimum: EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  spacing: 20,
                  children: [
                    if (exerciseLogs.isNotEmpty)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: GridView.count(
                              crossAxisCount: 2,
                              childAspectRatio: 1,
                              mainAxisSpacing: 10.0,
                              crossAxisSpacing: 10.0,
                              children: children),
                        ),
                      ),
                    if (_isRoutinePartiallyComplete())
                      SafeArea(
                        minimum: EdgeInsets.symmetric(horizontal: 20),
                        child: SizedBox(
                            width: double.infinity,
                            child: OpacityButtonWidgetTwo(
                              buttonColor:
                                  Theme.of(context).colors.vibrantAccent,
                              label: widget.mode == RoutineEditorMode.log
                                  ? "Finish Session"
                                  : "Update Session",
                              onPressed: widget.mode == RoutineEditorMode.log
                                  ? _saveLog
                                  : _updateLog,
                            )),
                      ),
                    if (exerciseLogs.isEmpty)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: const NoListEmptyState(
                              message:
                                  "Tap the + button to start adding exercises to your workout session"),
                        ),
                      ),
                  ],
                ),
              ),
            )));
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _loadRoutineAndExerciseLogs();
  }

  void _loadRoutineAndExerciseLogs() {
    final exerciseAndRoutineController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);

    final exerciseLogController =
        Provider.of<ExerciseLogController>(context, listen: false);

    exerciseLogController.loadRoutineLog(routineLog: widget.log);

    final exerciseLogs = widget.mode == RoutineEditorMode.log
        ? widget.log.exerciseLogs.map((exerciseLog) {
            if (!widget.cached) {
              // Find the most recent log for this template (excluding the current log if it exists)
              final templateId = widget.log.templateId;
              List<RoutineLogDto> templateLogs;
              if (templateId.isNotEmpty) {
                templateLogs = exerciseAndRoutineController
                    .whereLogsWithTemplateId(templateId: templateId)
                    .where(
                        (log) => log.id != widget.log.id) // Exclude current log
                    .toList();
              } else {
                templateLogs = [];
              }

              // If we have a template and previous logs, use sets from the most recent log
              if (templateLogs.isNotEmpty) {
                // Sort logs by startTime (most recent first)
                final sortedLogs = List<RoutineLogDto>.from(templateLogs)
                  ..sort((a, b) => b.startTime.compareTo(a.startTime));
                final mostRecentLog = sortedLogs.first;

                // Find this exercise in the most recent log
                final exerciseLogInMostRecentLog = mostRecentLog.exerciseLogs
                    .where((el) => el.exercise.id == exerciseLog.exercise.id)
                    .firstOrNull;

                if (exerciseLogInMostRecentLog != null) {
                  // Use sets from the most recent log, unchecked
                  final uncheckedSets = exerciseLogInMostRecentLog.sets
                      .map((set) => set.copyWith(checked: false))
                      .toList();

                  /// Don't add any previous set for [ExerciseType.Duration]
                  /// Duration is captured in realtime from a fresh instance
                  return exerciseLog.copyWith(
                      sets: withReps(type: exerciseLog.exercise.type)
                          ? uncheckedSets
                          : []);
                }
              }

              // Fallback: no template logs or exercise not found - return original exercise log
              // (which contains the template's sets from widget.log)
              /// Don't add any previous set for [ExerciseType.Duration]
              /// Duration is captured in realtime from a fresh instance
              return exerciseLog.copyWith(
                  sets: withReps(type: exerciseLog.exercise.type)
                      ? exerciseLog.sets
                          .map((set) => set.copyWith(checked: false))
                          .toList()
                      : []);
            }
            return exerciseLog;
          }).toList()
        : widget.log.exerciseLogs;
    exerciseLogController.loadExerciseLogs(exerciseLogs: exerciseLogs);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Don't auto-clear cache on dispose - only clear on successful save
    if (Platform.isIOS) {
      FlutterLocalNotificationsPlugin()
          .cancel(notificationIDLongRunningSession);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (Platform.isIOS) {
        FlutterLocalNotificationsPlugin()
            .cancel(notificationIDLongRunningSession);
      }
    }

    if (state == AppLifecycleState.paused) {
      if (Platform.isIOS) {
        FlutterLocalNotificationsPlugin().periodicallyShowWithDuration(
            notificationIDLongRunningSession,
            "${widget.log.name} is still running",
            "Tap to continue training",
            const Duration(minutes: 10),
            const NotificationDetails(
              iOS: DarwinNotificationDetails(
                presentAlert: false,
                presentBadge: false,
                presentSound: false,
                presentBanner: false,
              ),
            ),
            androidScheduleMode: AndroidScheduleMode.exact);
      }
    }
  }
}

// Removed in-session info banner
