import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:trainware/controllers/exercise_log_controller.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';
import 'package:trainware/enums/muscle_group_enums.dart';
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

const Duration _suggestionHistoryWindow = Duration(days: 30);

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
  Duration? _averageSessionDuration;
  bool _showSuggestionsBar = false;
  bool _suggestionsExpanded = false;
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

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed = DateTime.now().difference(widget.log.startTime);
        if (_elapsed.isNegative) {
          _elapsed = Duration.zero;
        }
      });
    });
  }

  void _handleSuggestedExerciseTap(ExerciseDto exercise) {
    final controller =
        Provider.of<ExerciseLogController>(context, listen: false);
    final pastSets = Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false)
        .whereRecentSetsForExercise(exercise: exercise);
    controller.addExerciseLog(exercise: exercise, pastSets: pastSets);
  }

  List<_SuggestionCardData> _buildSuggestionCards() {
    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);
    final logs = controller.logs;
    if (logs.isEmpty) return [];

    final now = DateTime.now();
    final todayWeekday = now.weekday;
    final cutoff = now.subtract(_suggestionHistoryWindow);

    final Map<String, _SuggestionStats> stats = {};

    for (final log in logs) {
      if (log.startTime.isBefore(cutoff)) continue;
      final sameWeekday = log.startTime.weekday == todayWeekday;
      for (final exerciseLog in log.exerciseLogs) {
        final exercise = exerciseLog.exercise;
        if (exercise.id.isEmpty) continue;
        final entry = stats.putIfAbsent(
          exercise.id,
          () => _SuggestionStats(exercise: exercise),
        );
        entry.totalCount++;
        if (sameWeekday) entry.weekdayCount++;
        if (entry.lastDate == null || log.startTime.isAfter(entry.lastDate!)) {
          entry.lastDate = log.startTime;
        }
      }
    }

    if (stats.isEmpty) return [];

    int compareStats(_SuggestionStats a, _SuggestionStats b) {
      if (a.weekdayCount != b.weekdayCount) {
        return b.weekdayCount.compareTo(a.weekdayCount);
      }
      if (a.totalCount != b.totalCount) {
        return b.totalCount.compareTo(a.totalCount);
      }
      final aDate = a.lastDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.lastDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    }

    final weekdayFavs = stats.values.where((s) => s.weekdayCount > 0).toList()
      ..sort(compareStats);
    final generalFavs = stats.values.where((s) => s.weekdayCount == 0).toList()
      ..sort(compareStats);

    final ordered = <_SuggestionStats>[];
    ordered.addAll(weekdayFavs);
    if (ordered.length < 5) {
      ordered.addAll(
        generalFavs.take(5 - ordered.length),
      );
    }

    return ordered.take(5).map((entry) {
      return _SuggestionCardData(
        exercise: entry.exercise,
      );
    }).toList();
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

  String _buildTimerDeltaLabel() {
    if (_averageSessionDuration == null) return "";
    final avg = _averageSessionDuration!;
    if (_elapsed <= avg) return "";

    final diff = _elapsed - avg;
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
                _buildTimerDeltaLabel(),
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

    final suggestionData = _showSuggestionsBar
        ? _buildSuggestionCards()
        : const <_SuggestionCardData>[];
    final activeExerciseIds =
        exerciseLogs.map((log) => log.exercise.id).toSet();
    final visibleSuggestions = suggestionData
        .where((entry) => !activeExerciseIds.contains(entry.exercise.id))
        .toList();

    // Always show suggestions if there are any visible suggestions
    final shouldShowSuggestions = visibleSuggestions.isNotEmpty;

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
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatElapsedDuration(_elapsed),
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
                                                _buildTimerDeltaLabel();
                                            if (deltaLabel.isEmpty) {
                                              return const SizedBox.shrink();
                                            }
                                            return Padding(
                                              padding:
                                                  const EdgeInsets.only(top: 2),
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
                            ? const _EmptySessionSuggestions()
                            : Column(
                                children: [
                                  Expanded(
                                    child: ReorderableListView.builder(
                                      padding: const EdgeInsets.only(
                                        top: 8,
                                      ),
                                      itemCount: exerciseLogs.length,
                                      onReorder: (oldIndex, newIndex) {
                                        if (newIndex > oldIndex) {
                                          newIndex -= 1;
                                        }

                                        final updated = exerciseLogs.toList();
                                        final item = updated.removeAt(oldIndex);
                                        updated.insert(newIndex, item);

                                        exerciseLogController
                                            .reOrderExerciseLogs(
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
                                          direction:
                                              DismissDirection.endToStart,
                                          confirmDismiss: (_) =>
                                              _confirmRemoveExercise(
                                                  exerciseLog),
                                          onDismissed: (_) {
                                            exerciseLogController
                                                .removeExerciseLog(
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
                    ],
                  ),
                ),
                if (shouldShowSuggestions)
                  Positioned(
                    left: -20,
                    right: -20,
                    bottom: _isRoutinePartiallyComplete() ? 100 : 20,
                    child: _RoutineLogSuggestionSheet(
                      weekdayLabel: DateFormat('EEEE').format(DateTime.now()),
                      suggestions: visibleSuggestions,
                      onAddExercise: _handleSuggestedExerciseTap,
                      isExpanded: _suggestionsExpanded,
                      onToggleExpanded: () {
                        setState(() {
                          _suggestionsExpanded = !_suggestionsExpanded;
                        });
                      },
                    ),
                  ),
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
      // Clear in-memory + cached pending routine log once session is saved.
      exerciseLogController.onClear();

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

    // Always show suggestions in RoutineLogEditorScreen (not in PastRoutineLogEditorScreen)
    _showSuggestionsBar = true;

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

// Removed in-session info banner

class _EmptySessionSuggestions extends StatelessWidget {
  const _EmptySessionSuggestions();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 100),
      child: Center(
        child: Text(
          'No exercises yet.\nTap + to add exercises and start logging.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _RoutineLogSuggestionSheet extends StatelessWidget {
  final String weekdayLabel;
  final List<_SuggestionCardData> suggestions;
  final void Function(ExerciseDto exercise) onAddExercise;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;

  const _RoutineLogSuggestionSheet({
    required this.weekdayLabel,
    required this.suggestions,
    required this.onAddExercise,
    required this.isExpanded,
    required this.onToggleExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      ignoring: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: (isDarkMode ? Colors.white : Colors.black)
                        .withValues(alpha: isDarkMode ? 0.06 : 0.05),
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      color: Theme.of(context)
                          .colors
                          .borderLight
                          .withValues(alpha: 0.1),
                    ),
                  ),
                  child: GestureDetector(
                    onTap: onToggleExpanded,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'You usually train these on $weekdayLabel',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ),
                          FaIcon(
                            isExpanded
                                ? FontAwesomeIcons.chevronDown
                                : FontAwesomeIcons.chevronUp,
                            size: 12,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (isExpanded) ...[
            const SizedBox(height: 12),
            _SuggestionRail(
              suggestions: suggestions,
              onAddExercise: onAddExercise,
            ),
          ],
        ],
      ),
    );
  }
}

class _SuggestionRail extends StatelessWidget {
  final List<_SuggestionCardData> suggestions;
  final void Function(ExerciseDto exercise) onAddExercise;

  const _SuggestionRail({
    required this.suggestions,
    required this.onAddExercise,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          for (int i = 0; i < suggestions.length; i++) ...[
            if (i != 0) const SizedBox(width: 14),
            _SuggestionCard(
              data: suggestions[i],
              onAdd: () => onAddExercise(suggestions[i].exercise),
            ),
          ],
        ],
      ),
    );
  }
}

class _SuggestionCardData {
  final ExerciseDto exercise;

  const _SuggestionCardData({
    required this.exercise,
  });
}

class _SuggestionStats {
  final ExerciseDto exercise;
  int weekdayCount = 0;
  int totalCount = 0;
  DateTime? lastDate;

  _SuggestionStats({required this.exercise});
}

class _SuggestionCard extends StatelessWidget {
  final _SuggestionCardData data;
  final VoidCallback onAdd;

  const _SuggestionCard({
    required this.data,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final MuscleGroup muscleGroup = data.exercise.primaryMuscleGroup;
    final muscleGroupLabel = muscleGroup.displayName;

    // Get muscle illustration path
    final illustrationPath = 'muscles_illustration/${muscleGroup.name}.png';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onAdd,
        borderRadius: BorderRadius.circular(20),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: (isDarkMode ? Colors.white : Colors.black)
                    .withValues(alpha: isDarkMode ? 0.06 : 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Theme.of(context)
                      .colors
                      .borderLight
                      .withValues(alpha: 0.1),
                ),
              ),
              child: Container(
                width: 240,
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.exercise.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                muscleGroupLabel,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Opacity(
                          opacity: 0.85,
                          child: Image.asset(
                            illustrationPath,
                            height: 32,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              // Fallback if image not found
                              return Icon(Icons.block,
                                  size: 32, color: Colors.white24);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
