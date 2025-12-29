import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:trainware/controllers/exercise_log_controller.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';
import 'package:trainware/utils/exercise_logs_utils.dart';
import 'package:trainware/utils/routine_editors_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';
import 'package:trainware/widgets/routine/editors/exercise_log_list_item.dart';

import '../../controllers/supabase_exercise_and_routine_controller.dart';
import '../../dtos/appsync/exercise_dto.dart';
import '../../enums/routine_editor_type_enums.dart';
import '../../utils/general_utils.dart';
import '../../utils/notifications_utils.dart';
import '../../extensions/duration_extension.dart';
import 'package:lottie/lottie.dart';
import '../../utils/lottie_exercise_registry.dart';

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
  Timer? _timer;
  Duration _elapsed = Duration.zero;
  final ValueNotifier<Duration> _elapsedNotifier =
      ValueNotifier<Duration>(Duration.zero);
  Duration? _averageSessionDuration;
  final Future<String?> _emptyStateLottieFuture =
      LottieExerciseRegistry.randomLottie();
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

  void _startTimer() {
    // Initialize elapsed based on the log's start time. Clamp to zero in case
    // the device clock has moved backwards (e.g. manual time change).
    _elapsed = DateTime.now().difference(widget.log.startTime);
    if (_elapsed.isNegative) {
      _elapsed = Duration.zero;
    }
    _elapsedNotifier.value = _elapsed;

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _elapsed = DateTime.now().difference(widget.log.startTime);
      if (_elapsed.isNegative) {
        _elapsed = Duration.zero;
      }
      _elapsedNotifier.value = _elapsed;
    });
  }

  void _loadAverageSessionDuration() {
    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);
    final logs = controller.logs;
    if (logs.isEmpty) return;

    final durations = logs
        .map((log) => log.endTime.difference(log.startTime))
        .where((d) => !d.isNegative && d.inMinutes > 0)
        .toList();

    if (durations.isEmpty) return;

    final totalSeconds = durations.fold<int>(0, (sum, d) => sum + d.inSeconds);
    final avgSeconds = totalSeconds ~/ durations.length;

    setState(() {
      _averageSessionDuration = Duration(seconds: avgSeconds);
    });
  }

  String _buildTimerDeltaLabel(Duration elapsed) {
    if (_averageSessionDuration == null) return "";
    final avg = _averageSessionDuration!;
    if (elapsed <= avg) return "";

    final diff = elapsed - avg;
    if (diff.inSeconds <= 0) return "";

    final diffLabel = _formatElapsedDuration(diff);
    return "$diffLabel over your usual session";
  }

  String _formatElapsedDuration(Duration duration) {
    return duration.inHours >= 1 ? duration.hmsDigital() : duration.msDigital();
  }

  void _showTimerInfoBottomSheet() {
    final avgText = _averageSessionDuration != null
        ? _averageSessionDuration!.hmsAnalog()
        : "not enough data yet";

    showAppBottomSheet(
      context: context,
      isScrollControlled: false,
      useBlurredTransparentBackground: false,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Session timer",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              "This timer shows how long this workout has been running, from when you first started the session.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Text(
              "Based on your past workouts, your average session lasts $avgText.",
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (_averageSessionDuration != null) ...[
              const SizedBox(height: 8),
              Text(
                _buildTimerDeltaLabel(_elapsedNotifier.value),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _isRoutinePartiallyComplete() {
    final exerciseLogController =
        Provider.of<ExerciseLogController>(context, listen: false);
    final exerciseLogs = exerciseLogController.exerciseLogs;
    return exerciseLogs.isNotEmpty &&
        exerciseLogs.any(
            (log) => log.sets.any((set) => set.isNotEmpty() && set.checked));
  }

  // initState is defined later once all helper methods are declared.

  @override
  Widget build(BuildContext context) {
    final isLogMode = widget.mode == RoutineEditorMode.log;
    final exerciseLogController =
        Provider.of<ExerciseLogController>(context, listen: false);

    final exerciseLogs = context
        .select((ExerciseLogController controller) => controller.exerciseLogs);

    // Suggestions removed

    return PopScope(
        canPop: true,
        child: Scaffold(
            body: Container(
          decoration: BoxDecoration(
            gradient: themeGradient(context: context),
          ),
          child: SafeArea(
            top: true,
            bottom:
                false, // let content (including the list) reach the bottom of the sheet
            left: true,
            right: true,
            minimum: const EdgeInsets.all(20),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Main content: header + list
                // Reserve vertical space at the bottom for the fixed CTA only
                // when it's visible, so the list doesn't scroll underneath it.
                Positioned.fill(
                  bottom: _isRoutinePartiallyComplete() ? 88.0 : 0.0,
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
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
                                if (isLogMode) ...[
                                  const SizedBox(height: 6),
                                  GestureDetector(
                                    onTap: _showTimerInfoBottomSheet,
                                    child: ValueListenableBuilder<Duration>(
                                      valueListenable: _elapsedNotifier,
                                      builder: (context, elapsed, _) {
                                        return Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _formatElapsedDuration(elapsed),
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .headlineSmall
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                            ),
                                            Builder(
                                              builder: (context) {
                                                final deltaLabel =
                                                    _buildTimerDeltaLabel(
                                                        elapsed);
                                                if (deltaLabel.isEmpty) {
                                                  return const SizedBox
                                                      .shrink();
                                                }
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                          top: 2),
                                                  child: Text(
                                                    deltaLabel,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: Colors.white70,
                                                          height: 1.2,
                                                        ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: _confirmDiscardSession,
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      minimumSize: const Size(0, 0),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                      foregroundColor: Colors.redAccent,
                                    ),
                                    child: Text(
                                      'Discard session',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.redAccent,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: _selectExercisesInLibrary,
                            icon: const FaIcon(
                              FontAwesomeIcons.circlePlus,
                              size: 22,
                              color: Colors.white,
                            ),
                            tooltip: 'Add exercises',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: exerciseLogs.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 100),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    spacing: 16,
                                    children: [
                                      SizedBox(
                                        width: 160,
                                        height: 160,
                                        child: FutureBuilder<String?>(
                                          future: _emptyStateLottieFuture,
                                          builder: (context, snapshot) {
                                            final asset = snapshot.data;
                                            if (asset != null) {
                                              return Lottie.asset(
                                                asset,
                                                fit: BoxFit.contain,
                                                repeat: true,
                                              );
                                            }
                                            return const Icon(
                                              Icons.self_improvement,
                                              size: 96,
                                              color: Colors.white38,
                                            );
                                          },
                                        ),
                                      ),
                                      Text(
                                        'No exercises yet.\nTap + to add exercises and start logging.',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w500,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ReorderableListView.builder(
                                padding: const EdgeInsets.only(
                                  top: 8,
                                  bottom: 72,
                                ),
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
                                proxyDecorator:
                                    (Widget child, int index, animation) {
                                  // Keep the dragged item visually identical
                                  // without additional background color.
                                  return Material(
                                    type: MaterialType.transparency,
                                    child: child,
                                  );
                                },
                                itemBuilder: (context, index) {
                                  final exerciseLog = exerciseLogs[index];
                                  return Dismissible(
                                    key: ValueKey(exerciseLog.id),
                                    direction: DismissDirection.endToStart,
                                    confirmDismiss: (_) =>
                                        _confirmRemoveExercise(exerciseLog),
                                    onDismissed: (_) {
                                      exerciseLogController.removeExerciseLog(
                                          logId: exerciseLog.id);
                                    },
                                    background: const SizedBox.shrink(),
                                    child: Column(
                                      children: [
                                        ExerciseLogListItem(
                                          exerciseLogDto: exerciseLog,
                                          onTap: () {
                                            showExerciseLogEditor(
                                              context: context,
                                              exerciseLogId:
                                                  exerciseLog.exercise.id,
                                              editorType: widget.mode,
                                            );
                                          },
                                        ),
                                        const SizedBox(height: 12),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                // Suggestions removed
                // Bottom fixed CTA (does not scroll) – same pattern as PastRoutineLogEditor
                if (_isRoutinePartiallyComplete())
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      minimum:
                          const EdgeInsets.only(left: 20, right: 20, bottom: 0),
                      child: SizedBox(
                        width: double.infinity,
                        child: OpacityButtonWidgetTwo(
                          buttonColor: Theme.of(context).colors.vibrantAccent,
                          label: widget.log.id.isNotEmpty
                              ? "Update Session"
                              : "Finish Session",
                          onPressed: _finishOrUpdateSession,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        )));
  }

  Future<bool> _confirmRemoveExercise(ExerciseLogDto exerciseLog) async {
    return confirmRemoveExerciseBottomSheet(
      context: context,
      exerciseName: exerciseLog.exercise.name,
      fromLabel: 'workout',
    );
  }

  Future<void> _confirmDiscardSession() async {
    bool shouldDiscard = false;

    await showAppBottomSheet(
      context: context,
      isScrollControlled: false,
      useBlurredTransparentBackground: false,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Discard session?",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Are you sure you want to discard this workout session? This cannot be undone.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OpacityButtonWidgetTwo(
                    label: 'Cancel',
                    showArrowRight: false,
                    onPressed: () {
                      Navigator.of(context).pop();
                      shouldDiscard = false;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OpacityButtonWidgetTwo(
                    label: 'Discard',
                    buttonColor: Colors.red,
                    showArrowRight: false,
                    onPressed: () {
                      Navigator.of(context).pop();
                      shouldDiscard = true;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (!shouldDiscard) return;

    // Clear both in-memory state and cached pending routine log.
    Provider.of<ExerciseLogController>(context, listen: false).onClear();

    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _finishOrUpdateSession() async {
    final exerciseLogController =
        Provider.of<ExerciseLogController>(context, listen: false);
    final exerciseLogs = exerciseLogController.exerciseLogs;

    if (exerciseLogs.isEmpty) return;

    final routineController = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);

    // For new sessions, we should capture the current time as the end time.
    // For existing sessions (updates), we must preserve the original end time
    // so that the logged duration remains accurate unless the user explicitly
    // edits it from the duration editor.
    final endTime = widget.log.id.isEmpty ? DateTime.now() : widget.log.endTime;

    final updatedLog = widget.log.copyWith(
      exerciseLogs: exerciseLogs,
      endTime: endTime,
    );

    final savedLog = await routineController.saveLog(logDto: updatedLog);

    if (!mounted) return;

    if (savedLog != null) {
      // Clear state after successfully saving session.
      await exerciseLogController.onClear();

      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop(savedLog);
      }
    } else {
      // If save failed, keep state and let user retry later.
      // Optional: surface an error snackbar in a follow-up iteration.
    }
  }

  void _loadRoutineAndExerciseLogs() {
    final exerciseAndRoutineController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);

    final exerciseLogController =
        Provider.of<ExerciseLogController>(context, listen: false);

    // Only cache if this is a live workout session (log mode) and either cached or new workout
    final shouldCache = widget.mode == RoutineEditorMode.log;
    exerciseLogController.loadRoutineLog(
        routineLog: widget.log, shouldCache: shouldCache);

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

                  /// Don't add previous sets for duration-based exercises.
                  /// Duration is captured in real time from a fresh instance.
                  return exerciseLog.copyWith(
                      sets: withReps(type: exerciseLog.exercise.type)
                          ? uncheckedSets
                          : []);
                }
              }

              // Fallback: no template logs or exercise not found - return original exercise log
              // (which contains the template's sets from widget.log)
              /// Don't add previous sets for duration-based exercises.
              /// Duration is captured in real time from a fresh instance.
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
    _timer?.cancel();
    _elapsedNotifier.dispose();
    // Don't auto-clear cache on dispose - only clear on successful save
    if (Platform.isIOS) {
      FlutterLocalNotificationsPlugin()
          .cancel(notificationIDLongRunningSession);
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final isLiveLog = widget.mode == RoutineEditorMode.log;

    if (state == AppLifecycleState.resumed) {
      if (isLiveLog) {
        _startTimer(); // Re-sync elapsed time with real clock after suspension.
      }
      if (Platform.isIOS) {
        FlutterLocalNotificationsPlugin()
            .cancel(notificationIDLongRunningSession);
      }
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      if (isLiveLog) {
        _timer?.cancel();
      }
      if (state == AppLifecycleState.paused && Platform.isIOS) {
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

  @override
  void initState() {
    super.initState();

    // Disable suggestions
    WidgetsBinding.instance.addObserver(this);

    _loadRoutineAndExerciseLogs();
    if (widget.mode == RoutineEditorMode.log) {
      _startTimer();
    }
    // Load average duration after first frame to ensure provider is ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadAverageSessionDuration();
      }
    });
  }
}
