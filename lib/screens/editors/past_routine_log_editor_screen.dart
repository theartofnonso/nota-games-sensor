import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:provider/provider.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/controllers/exercise_log_controller.dart';
import 'package:trainware/dtos/appsync/exercise_dto.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';
import 'package:trainware/enums/routine_editor_type_enums.dart';
import 'package:trainware/utils/dialog_utils.dart';
import 'package:trainware/utils/session_duration_selector.dart';
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';

import 'package:trainware/utils/theme/color_extensions.dart';
import '../../dtos/appsync/routine_log_dto.dart';
import '../../dtos/set_dtos/set_dto.dart';
import '../../dtos/set_dtos/weight_and_reps_dto.dart';
import '../../utils/general_utils.dart';
import '../../utils/routine_editors_utils.dart';
import '../../widgets/buttons/opacity_button_widget_two.dart';
import '../../widgets/routine/editors/exercise_log_list_item.dart';
import '../../widgets/weight_plate_calculator.dart';

class PastRoutineLogEditorScreen extends StatefulWidget {
  static const routeName = '/past-routine-log-editor';

  final RoutineLogDto log;

  const PastRoutineLogEditorScreen({super.key, required this.log});

  @override
  State<PastRoutineLogEditorScreen> createState() =>
      _PastRoutineLogEditorScreenState();
}

class _PastRoutineLogEditorScreenState
    extends State<PastRoutineLogEditorScreen> {
  late TextEditingController _templateNameController;

  late DateTime _startTime;
  late DateTime _endTime;

  final _minimisedExerciseLogCards = <String>[];

  SetDto? _selectedSetDto;

  void _selectExercisesInLibrary() async {
    final controller =
        Provider.of<ExerciseLogController>(context, listen: false);
    final excludeExercises =
        controller.exerciseLogs.map((exercise) => exercise.exercise).toList();

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

  bool _validateRoutineTemplateInputs() {
    if (_templateNameController.text.isEmpty) {
      _showSnackbar('Please provide a name for this workout');
      return false;
    }
    return true;
  }

  void _showSnackbar(String message) {
    showSnackbar(context: context, message: message);
  }

  bool _isRoutinePartiallyComplete() {
    final exerciseLogController =
        Provider.of<ExerciseLogController>(context, listen: false);
    final exerciseLogs = exerciseLogController.exerciseLogs;
    return exerciseLogs.isNotEmpty &&
        exerciseLogs.any(
            (log) => log.sets.any((set) => set.isNotEmpty() && set.checked));
  }

  void _createLog() async {
    if (!_validateRoutineTemplateInputs()) return;

    // Show duration selector bottom sheet
    await showSessionDurationSelectorBottomSheet(
      context: context,
      initialStartTime: _startTime,
      initialEndTime: _endTime,
      onConfirm: (start, end) async {
        setState(() {
          _startTime = start;
          _endTime = end;
        });
        await _saveLogWithDuration();
      },
    );
  }

  Future<void> _saveLogWithDuration() async {
    // Validation is handled by the shared duration selector.
    final exerciseLogController =
        Provider.of<ExerciseLogController>(context, listen: false);

    final exerciseLogs = exerciseLogController.exerciseLogs.map((exerciseLog) {
      final checkedSets =
          exerciseLog.sets.map((set) => set.copyWith(checked: true)).toList();
      return exerciseLog.copyWith(sets: checkedSets);
    }).toList();

    final routineName = _templateNameController.text.trim().isNotEmpty
        ? _templateNameController.text.trim()
        : widget.log.name;
    final updatedLog = widget.log.copyWith(
        name: routineName,
        exerciseLogs: exerciseLogs,
        startTime: _startTime,
        endTime: _endTime);

    final createdLog = await Provider.of<SupabaseExerciseAndRoutineController>(
            context,
            listen: false)
        .saveLog(logDto: updatedLog);

    // Check mounted after async operation
    if (!mounted) return;

    // Clear local controller state ONLY if save succeeded.
    // Do not touch any pending live workout cache.
    if (createdLog != null) {
      Provider.of<ExerciseLogController>(context, listen: false).clearLocal();
    }

    // Always exit regardless of save success/failure
    _navigateBack(log: createdLog);
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  void _navigateBack({RoutineLogDto? log}) {
    Navigator.of(context).pop(log);
  }

  Future<bool> _confirmRemoveExercise(ExerciseLogDto exerciseLog) async {
    return confirmRemoveExerciseBottomSheet(
      context: context,
      exerciseName: exerciseLog.exercise.name,
      fromLabel: 'log',
    );
  }

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    final exerciseLogController =
        Provider.of<ExerciseLogController>(context, listen: false);

    final routineTemplateController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: true);

    if (routineTemplateController.errorMessage.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSnackbar(routineTemplateController.errorMessage);
      });
    }

    final exerciseLogs = context
        .select((ExerciseLogController provider) => provider.exerciseLogs);

    bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom != 0;

    return PopScope(
      canPop: true,
      child: Scaffold(
        floatingActionButton: isKeyboardOpen
            ? SafeArea(
                minimum: EdgeInsets.only(left: 32),
                child: Row(children: [
                  FloatingActionButton(
                    heroTag: UniqueKey(),
                    onPressed: _dismissKeyboard,
                    enableFeedback: true,
                    child: FaIcon(Icons.keyboard_hide_rounded),
                  ),
                  Spacer(),
                  _selectedSetDto != null
                      ? FloatingActionButton(
                          heroTag: UniqueKey(),
                          onPressed: _showWeightCalculator,
                          enableFeedback: true,
                          child: Image.asset(
                            'icons/dumbbells.png',
                            fit: BoxFit.contain,
                            color: isDarkMode ? Colors.white : Colors.white,
                            height: 24, // Adjust the height as needed
                          ),
                        )
                      : SizedBox.shrink()
                ]),
              )
            : null,
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Container(
              decoration: BoxDecoration(
                gradient: themeGradient(context: context),
              ),
              child: SafeArea(
                top: true,
                bottom: false,
                left: true,
                right: true,
                minimum: const EdgeInsets.only(
                  top: 20,
                  left: 20,
                  right: 20,
                  bottom: 0,
                ),
                child: Stack(
                  children: [
                    // Main scrollable content (name + list)
                    Positioned.fill(
                      bottom: _isRoutinePartiallyComplete() ? 88.0 : 0.0,
                      child: GestureDetector(
                        onTap: _dismissKeyboard,
                        child: Column(
                          children: [
                            // Header: past routine name + add button (top-right)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
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
                            ),
                            Expanded(
                              child: exerciseLogs.isEmpty
                                  ? Center(
                                      child: Text(
                                        'No exercises in this log yet.\nTap + to add exercises.',
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: Colors.white70,
                                            ),
                                      ),
                                    )
                                  : ReorderableListView.builder(
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
                                                    editorType:
                                                        RoutineEditorMode.edit,
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
                              buttonColor:
                                  Theme.of(context).colors.vibrantAccent,
                              label: "Log Past Session",
                              onPressed: _createLog,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showWeightCalculator() {
    showAppBottomSheet(
        context: context,
        isScrollControlled: false,
        child: WeightPlateCalculator(
            target: (_selectedSetDto as WeightAndRepsSetDto?)?.weight ?? 0));
  }

  @override
  void initState() {
    super.initState();

    _initializeProcedureData();
    _initializeTextControllers();
  }

  void _initializeProcedureData() {
    // Clear controller first to ensure clean state when opening a new past session,
    // but do NOT clear any pending live workout cache.
    Provider.of<ExerciseLogController>(context, listen: false).clearLocal();

    final exercises = widget.log.exerciseLogs;
    if (exercises.isNotEmpty) {
      final controller = Provider.of<SupabaseExerciseAndRoutineController>(
          context,
          listen: false);

      // Find the most recent log for this template (excluding the current log if it exists)
      final templateId = widget.log.templateId;
      List<RoutineLogDto> templateLogs;
      if (templateId.isNotEmpty) {
        templateLogs = controller
            .whereLogsWithTemplateId(templateId: templateId)
            .where((log) => log.id != widget.log.id) // Exclude current log
            .toList();
      } else {
        templateLogs = [];
      }

      final updatedExerciseLogs = exercises.map((exerciseLog) {
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
            // Use sets from the most recent log, unchecked, matching the number of sets
            final unCheckedSets = exerciseLogInMostRecentLog.sets
                .take(exerciseLog.sets.length)
                .map((set) => set.copyWith(checked: false))
                .toList();
            return exerciseLog.copyWith(sets: unCheckedSets);
          }
        }

        // Fallback: no template logs or exercise not found - return original exercise log
        return exerciseLog;
      }).toList();

      Provider.of<ExerciseLogController>(context, listen: false)
          .loadExerciseLogs(exerciseLogs: updatedExerciseLogs);
      _minimiseOrMaximiseCards();
    }
  }

  void _initializeTextControllers() {
    final log = widget.log;
    _templateNameController = TextEditingController(text: log.name);

    // Initialize start and end times: default to 1 hour ago from current time
    // If startTime == endTime, it's the initial state (both set to the selected date)
    // In that case, use default times: 1 hour ago to now, preserving the selected date
    if (log.startTime == log.endTime) {
      // Initial state - use default times (1 hour duration from current time)
      // But preserve the date portion from the log
      final now = DateTime.now();
      final defaultStartTime = now.subtract(const Duration(hours: 1));
      final selectedDate =
          DateTime(log.startTime.year, log.startTime.month, log.startTime.day);

      // Set times on the selected date, but with current time - 1 hour and current time
      _startTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        defaultStartTime.hour,
        defaultStartTime.minute,
      );
      _endTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        now.hour,
        now.minute,
      );
    } else {
      // User has already set times - use them
      _startTime = log.startTime;
      _endTime = log.endTime;
    }
  }

  void _minimiseOrMaximiseCards() {
    Provider.of<ExerciseLogController>(context, listen: false)
        .exerciseLogs
        .forEach((exerciseLog) {
      final completedSets = exerciseLog.sets.where((set) => set.checked).length;
      final isExerciseCompleted = completedSets == exerciseLog.sets.length;
      if (isExerciseCompleted) {
        setState(() {
          _minimisedExerciseLogCards.add(exerciseLog.id);
        });
      }
    });
  }

  @override
  void dispose() {
    // Don't auto-clear cache on dispose - only clear on successful save
    _templateNameController.dispose();
    super.dispose();
  }
}
