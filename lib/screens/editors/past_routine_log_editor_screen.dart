import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import 'package:tracker_app/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:tracker_app/controllers/exercise_log_controller.dart';
import 'package:tracker_app/dtos/appsync/exercise_dto.dart';
import 'package:tracker_app/dtos/exercise_log_dto.dart';
import 'package:tracker_app/enums/routine_editor_type_enums.dart';
import 'package:tracker_app/utils/dialog_utils.dart';
import 'package:tracker_app/widgets/bottom_sheets/app_bottom_sheet.dart';

import 'package:tracker_app/utils/theme/color_extensions.dart';
import '../../dtos/appsync/routine_log_dto.dart';
import '../../dtos/set_dtos/set_dto.dart';
import '../../dtos/set_dtos/weight_and_reps_dto.dart';
import '../../extensions/datetime/datetime_extension.dart';
import '../../extensions/duration_extension.dart';
import '../../strings/datetime_range_picker_strings.dart';
import '../../utils/general_utils.dart';
import '../../utils/routine_editors_utils.dart';
import '../../utils/routine_utils.dart';
import '../../widgets/buttons/opacity_button_widget_two.dart';
import '../../widgets/empty_states/no_list_empty_state.dart';
import '../../widgets/routine/editors/exercise_log_grid_item.dart';
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
  late TextEditingController _templateNotesController;

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
        controller.exerciseLogs.map((exercise) => exercise.exercise).toList();

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
    _showDurationSelectorBottomSheet();
  }

  void _showDurationSelectorBottomSheet() {
    showAppBottomSheet(
      context: context,
      isScrollControlled: true,
      child: StatefulBuilder(
        builder:
            (BuildContext bottomSheetContext, StateSetter setBottomSheetState) {
          return Padding(
            padding: const EdgeInsets.all(26.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Select Duration",
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Set the start and end times for this session",
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white70,
                      ),
                ),
                const SizedBox(height: 24),
                // Start Time Selector
                _DurationSelectorRow(
                  label: "Start Time",
                  dateTime: _startTime,
                  onTimeChanged: (DateTime newDateTime) {
                    setState(() {
                      _startTime = newDateTime;
                    });
                    setBottomSheetState(() {});
                  },
                ),
                const SizedBox(height: 16),
                // End Time Selector
                _DurationSelectorRow(
                  label: "End Time",
                  dateTime: _endTime,
                  onTimeChanged: (DateTime newDateTime) {
                    setState(() {
                      _endTime = newDateTime;
                    });
                    setBottomSheetState(() {});
                  },
                ),
                const SizedBox(height: 24),
                // Log Session Button with validation state
                Builder(
                  builder: (context) {
                    final errorMessage = _validateDuration();
                    final duration = _endTime.difference(_startTime);
                    final isValid = errorMessage == null;

                    return OpacityButtonWidgetTwo(
                      buttonColor: isValid
                          ? Theme.of(context).colors.vibrantAccent
                          : Colors.grey,
                      label: isValid
                          ? "Log ${duration.hmsAnalog()} session"
                          : "Log Session",
                      onPressed: isValid
                          ? () {
                              Navigator.of(context).pop();
                              _saveLogWithDuration();
                            }
                          : null, // Disable button when invalid
                    );
                  },
                )
              ],
            ),
          );
        },
      ),
    );
  }

  String? _validateDuration() {
    // Check if start and end times are the same (zero duration)
    if (_startTime.millisecondsSinceEpoch == _endTime.millisecondsSinceEpoch) {
      return editZeroDurationRestriction;
    }

    if (_startTime.isAfter(_endTime)) {
      return editStartDateMustBeBeforeEndDate;
    }

    if (_endTime.isBefore(_startTime)) {
      return editEndDateMustBeAfterStartDate;
    }

    if (_endTime.millisecondsSinceEpoch >
        DateTime.now().millisecondsSinceEpoch) {
      return editFutureDateRestriction;
    }

    Duration difference = _endTime.difference(_startTime);

    if (difference.inHours > 24) {
      return edit24HourRestriction;
    }

    return null;
  }

  void _saveLogWithDuration() async {
    // Validate before saving
    final errorMessage = _validateDuration();
    if (errorMessage != null) {
      _showSnackbar(errorMessage);
      return;
    }
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
    final routineNotes = _templateNotesController.text.trim().isNotEmpty
        ? _templateNotesController.text.trim()
        : widget.log.notes;

    final updatedLog = widget.log.copyWith(
        name: routineName,
        notes: routineNotes,
        exerciseLogs: exerciseLogs,
        startTime: _startTime,
        endTime: _endTime);

    final createdLog = await Provider.of<SupabaseExerciseAndRoutineController>(
            context,
            listen: false)
        .saveLog(logDto: updatedLog);

    // Check mounted after async operation
    if (!mounted) return;

    // Clear cache ONLY if save succeeded
    if (createdLog != null) {
      Provider.of<ExerciseLogController>(context, listen: false).onClear();
    }

    // Always exit regardless of save success/failure
    _navigateBack(log: createdLog);
  }

  void _checkForUnsavedChanges() {
    final exerciseProvider =
        Provider.of<ExerciseLogController>(context, listen: false);
    final exerciseLog1 = widget.log.exerciseLogs;
    final exerciseLog2 = exerciseProvider.exerciseLogs;
    final unsavedChangesMessage =
        checkForChanges(exerciseLog1: exerciseLog1, exerciseLog2: exerciseLog2);
    if (unsavedChangesMessage.isNotEmpty) {
      showBottomSheetWithMultiActions(
          context: context,
          description: "You have unsaved changes",
          leftAction: _closeDialog,
          leftActionLabel: 'Cancel',
          rightAction: () {
            _closeDialog();
            // Clear controller when user explicitly discards
            Provider.of<ExerciseLogController>(context, listen: false)
                .onClear();
            _navigateBack();
          },
          rightActionLabel: 'Discard',
          isRightActionDestructive: true,
          title: "Discard changes");
    } else {
      // Clear controller even when no changes (to ensure clean state)
      Provider.of<ExerciseLogController>(context, listen: false).onClear();
      _navigateBack();
    }
  }

  void _reOrderExerciseLogs(
      {required List<ExerciseLogDto> exerciseLogs}) async {
    final orderedList =
        await reOrderExerciseLogs(context: context, exerciseLogs: exerciseLogs);
    if (!mounted) {
      return;
    }
    if (orderedList != null) {
      Provider.of<ExerciseLogController>(context, listen: false)
          .reOrderExerciseLogs(reOrderedList: orderedList);
    }
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  void _closeDialog() {
    context.pop();
  }

  void _navigateBack({RoutineLogDto? log}) {
    Navigator.of(context).pop(log);
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

    final children = exerciseLogs.map((exerciseLog) {
      return ExerciseLogGridItemWidget(
        editorType: RoutineEditorMode.edit,
        isPastRoutine: true,
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
                onPressed: _checkForUnsavedChanges),
            actions: [
              IconButton(
                  onPressed: _selectExercisesInLibrary,
                  icon: const FaIcon(FontAwesomeIcons.solidSquarePlus)),
              if (exerciseLogs.length > 1)
                IconButton(
                    onPressed: () =>
                        _reOrderExerciseLogs(exerciseLogs: exerciseLogs),
                    icon: const FaIcon(FontAwesomeIcons.barsStaggered)),
            ],
          ),
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
          body: Container(
            decoration: BoxDecoration(
              gradient: themeGradient(context: context),
            ),
            child: SafeArea(
              bottom: false,
              minimum:
                  const EdgeInsets.only(right: 10.0, bottom: 10.0, left: 10.0),
              child: GestureDetector(
                onTap: _dismissKeyboard,
                child: Column(
                  spacing: 20,
                  children: [
                    Column(
                      spacing: 10,
                      children: [
                        const SizedBox(height: 10),
                        TextField(
                          controller: _templateNameController,
                          cursorColor: isDarkMode ? Colors.white : Colors.black,
                          decoration: InputDecoration(
                            hintText: "New workout",
                          ),
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.words,
                          style: TextStyle(
                              fontWeight: FontWeight.w400,
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontSize: 14),
                        ),
                        TextField(
                          controller: _templateNotesController,
                          cursorColor: isDarkMode ? Colors.white : Colors.black,
                          decoration: InputDecoration(
                            hintText: "Notes (optional)",
                          ),
                          maxLines: null,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.sentences,
                          style: TextStyle(
                              fontWeight: FontWeight.w400,
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontSize: 14),
                        ),
                      ],
                    ),
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
                    if (exerciseLogs.isEmpty)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: const NoListEmptyState(
                              message:
                                  "Tap the + button to start adding exercises to your workout session"),
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
                                label: "Log Past Session",
                                onPressed: _createLog)),
                      )
                  ],
                ),
              ),
            ),
          )),
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
    // Clear controller first to ensure clean state when opening a new past session
    Provider.of<ExerciseLogController>(context, listen: false).onClear();

    final exercises = widget.log.exerciseLogs;
    if (exercises.isNotEmpty) {
      final updatedExerciseLogs = exercises.map((exerciseLog) {
        final previousSets = Provider.of<SupabaseExerciseAndRoutineController>(
                context,
                listen: false)
            .whereRecentSetsForExercise(exercise: exerciseLog.exercise);
        if (previousSets.isNotEmpty) {
          final unCheckedSets = previousSets
              .take(exerciseLog.sets.length)
              .map((set) => set.copyWith(checked: false))
              .toList();
          return exerciseLog.copyWith(sets: unCheckedSets);
        }
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
    _templateNotesController = TextEditingController(text: log.notes);

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
    _templateNotesController.dispose();
    super.dispose();
  }
}

// Widget for duration selector row in the bottom sheet with embedded time picker
class _DurationSelectorRow extends StatefulWidget {
  final String label;
  final DateTime dateTime;
  final void Function(DateTime newDateTime) onTimeChanged;

  const _DurationSelectorRow({
    required this.label,
    required this.dateTime,
    required this.onTimeChanged,
  });

  @override
  State<_DurationSelectorRow> createState() => _DurationSelectorRowState();
}

class _DurationSelectorRowState extends State<_DurationSelectorRow> {
  late DateTime _currentDateTime;

  @override
  void initState() {
    super.initState();
    _currentDateTime = widget.dateTime;
  }

  @override
  void didUpdateWidget(_DurationSelectorRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.dateTime != oldWidget.dateTime) {
      _currentDateTime = widget.dateTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label and Date/Time Display
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        "${_currentDateTime.day} ${_currentDateTime.abbreviatedMonth()}",
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        "${_currentDateTime.hour.toString().padLeft(2, '0')}:${_currentDateTime.minute.toString().padLeft(2, '0')}",
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: Theme.of(context).colors.vibrantAccent,
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Embedded Time Picker - always visible, compact height
        Container(
          height: 120,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: CupertinoDatePicker(
            mode: CupertinoDatePickerMode.time,
            use24hFormat: true,
            initialDateTime: _currentDateTime,
            itemExtent: 40,
            onDateTimeChanged: (DateTime value) {
              setState(() {
                // Keep the same date, only update time
                _currentDateTime = DateTime(
                  _currentDateTime.year,
                  _currentDateTime.month,
                  _currentDateTime.day,
                  value.hour,
                  value.minute,
                );
              });
              widget.onTimeChanged(_currentDateTime);
            },
          ),
        ),
      ],
    );
  }
}
