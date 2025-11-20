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
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';
import 'package:trainware/widgets/routine/editors/exercise_log_list_item.dart';
import 'package:trainware/screens/editors/_add_exercise_list_item.dart';

import 'package:trainware/utils/theme/color_extensions.dart';
import '../../controllers/supabase_exercise_and_routine_controller.dart';
import '../../dtos/appsync/exercise_dto.dart';
import '../../enums/routine_editor_type_enums.dart';
import '../../utils/general_utils.dart';
import '../../utils/notifications_utils.dart';
import '../../utils/routine_utils.dart';
import '../../widgets/buttons/opacity_button_widget_two.dart';

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

    return PopScope(
        canPop: false,
        child: Scaffold(
            body: Container(
          decoration: BoxDecoration(
            gradient: themeGradient(context: context),
          ),
          child: SafeArea(
            minimum: EdgeInsets.symmetric(vertical: 10),
            child: Stack(
              children: [
                // Main content: header + list + "Add exercises"
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 0),
                    child: Column(
                      children: [
                        // Header: routine name
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              widget.log.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child: ReorderableListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  itemCount: exerciseLogs.length,
                                  onReorder: (oldIndex, newIndex) {
                                    if (newIndex > oldIndex) {
                                      newIndex -= 1;
                                    }

                                    final updated = exerciseLogs.toList();
                                    final item = updated.removeAt(oldIndex);
                                    updated.insert(newIndex, item);

                                    exerciseLogController.reOrderExerciseLogs(
                                      reOrderedList: updated,
                                    );
                                  },
                                  itemBuilder: (context, index) {
                                    final exerciseLog = exerciseLogs[index];
                                    final superSet =
                                        whereOtherExerciseInSuperSet(
                                            firstExercise: exerciseLog,
                                            exercises: exerciseLogs);

                                    return Column(
                                      key: ValueKey(exerciseLog.id),
                                      children: [
                                        ExerciseLogListItem(
                                          exerciseLogDto: exerciseLog,
                                          superSet: superSet,
                                          onTap: () {
                                            showExerciseLogEditor(
                                              context: context,
                                              exerciseLogId:
                                                  exerciseLog.exercise.id,
                                              editorType: widget.mode,
                                            );
                                          },
                                          onMenuTap: () {
                                            _showExerciseActionsBottomSheet(
                                              exerciseLog: exerciseLog,
                                              onRemoveLog: () {
                                                exerciseLogController
                                                    .removeExerciseLog(
                                                        logId: exerciseLog.id);
                                              },
                                              onReplaceLog: () {
                                                _showReplaceExercisePicker(
                                                  oldExerciseLog: exerciseLog,
                                                );
                                              },
                                              onSuperSet: () {
                                                _showSuperSetExercisePicker(
                                                  firstExerciseLog: exerciseLog,
                                                );
                                              },
                                              onRemoveSuperSet:
                                                  (String superSetId) {
                                                exerciseLogController
                                                    .removeSuperSet(
                                                        superSetId: exerciseLog
                                                            .superSetId);
                                              },
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 12),
                              AddExerciseListItem(
                                onTap: _selectExercisesInLibrary,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 90),
                      ],
                    ),
                  ),
                ),
                // Top overlay controls (back + add), matching Overview style
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: IconButton(
                        icon: const FaIcon(FontAwesomeIcons.arrowLeftLong,
                            size: 18),
                        onPressed: _discardLog,
                        color: Colors.white,
                        padding: const EdgeInsets.all(12),
                        constraints: const BoxConstraints(),
                      ),
                    ),
                  ),
                ),
                // Bottom fixed CTA (does not scroll) – vertically aligned similar to Overview FAB
                if (_isRoutinePartiallyComplete())
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      minimum: const EdgeInsets.only(
                          left: 20, right: 20, bottom: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OpacityButtonWidgetTwo(
                          buttonColor: Theme.of(context).colors.vibrantAccent,
                          label: widget.mode == RoutineEditorMode.log
                              ? "Finish Session"
                              : "Update Session",
                          onPressed: widget.mode == RoutineEditorMode.log
                              ? _saveLog
                              : _updateLog,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        )));
  }

  void _showExerciseActionsBottomSheet({
    required ExerciseLogDto exerciseLog,
    required VoidCallback onRemoveLog,
    required VoidCallback onReplaceLog,
    required VoidCallback onSuperSet,
    required void Function(String superSetId) onRemoveSuperSet,
  }) {
    showAppBottomSheet(
        context: context,
        isScrollControlled: false,
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const FaIcon(
                FontAwesomeIcons.arrowRightArrowLeft,
                size: 18,
              ),
              horizontalTitleGap: 6,
              title: const Text("Replace"),
              onTap: () {
                Navigator.of(context).pop();
                onReplaceLog();
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const FaIcon(FontAwesomeIcons.link, size: 18),
              horizontalTitleGap: 6,
              title: const Text("Superset"),
              onTap: () {
                Navigator.of(context).pop();
                onSuperSet();
              },
            ),
            if (exerciseLog.superSetId.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const FaIcon(FontAwesomeIcons.linkSlash, size: 18),
                horizontalTitleGap: 6,
                title: const Text("Remove from superset"),
                onTap: () {
                  Navigator.of(context).pop();
                  onRemoveSuperSet(exerciseLog.superSetId);
                },
              ),
            ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const FaIcon(
                  FontAwesomeIcons.trash,
                  size: 18,
                  color: Colors.red,
                ),
                horizontalTitleGap: 6,
                title: const Text("Remove",
                    style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.w500,
                        fontSize: 16)),
                onTap: () {
                  Navigator.of(context).pop();
                  onRemoveLog();
                }),
          ]),
        ));
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
