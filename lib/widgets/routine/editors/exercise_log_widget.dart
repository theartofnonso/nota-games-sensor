import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:trainware/colors.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/controllers/exercise_log_controller.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';
import 'package:trainware/dtos/set_dtos/duration_set_dto.dart';
import 'package:trainware/enums/exercise_type_enums.dart';
import 'package:trainware/utils/dialog_utils.dart';
import 'package:trainware/utils/exercise_logs_utils.dart';
import 'package:trainware/utils/sets_utils.dart';
import 'package:trainware/utils/string_utils.dart';
import 'package:trainware/widgets/routine/editors/set_rows/duration_set_row.dart';
import 'package:trainware/widgets/routine/editors/set_rows/reps_set_row.dart';
import 'package:trainware/widgets/routine/editors/set_rows/weights_and_reps_set_row.dart';

import '../../../dtos/set_dtos/reps_dto.dart';
import '../../../dtos/set_dtos/set_dto.dart';
import '../../../dtos/set_dtos/weight_and_reps_dto.dart';
import '../../../enums/routine_editor_type_enums.dart';
import '../../../screens/exercise/history/exercise_home_screen.dart';
import '../../../utils/general_utils.dart';
import '../../bottom_sheets/app_bottom_sheet.dart';
import '../../empty_states/no_list_empty_state.dart';
import '../../timers/duration_stopwatch_widget.dart';
import '../../weight_plate_calculator.dart';

class ExerciseLogWidget extends StatefulWidget {
  final RoutineEditorMode editorType;
  final String exerciseLogId;
  final bool showSetCheck;

  const ExerciseLogWidget(
      {super.key,
      this.editorType = RoutineEditorMode.edit,
      required this.exerciseLogId,
      this.showSetCheck = true});

  @override
  State<ExerciseLogWidget> createState() => _ExerciseLogWidgetState();
}

class _ExerciseLogWidgetState extends State<ExerciseLogWidget> {
  ExerciseLogDto? _exerciseLog;

  List<(TextEditingController, TextEditingController)>
      _weightAndRepsControllers = [];
  List<TextEditingController> _repsControllers = [];
  List<DateTime> _durationControllers = [];

  SetDto? _selectedSetDto;

  final GlobalKey<DurationStopwatchWidgetState> _durationStopwatchKey =
      GlobalKey();

  final _errors = <int, String>{};

  late TextEditingController _notesController;
  final FocusNode _notesFocusNode = FocusNode();

  bool _hasShownProgressionPrompt = false;

  /// Get the current exercise log, throwing if it doesn't exist
  /// This should only be called after null checks in build method
  ExerciseLogDto get _currentExerciseLog {
    if (_exerciseLog == null) {
      throw StateError('Exercise log not found');
    }
    return _exerciseLog!;
  }

  void _updateExerciseLogNotes({required String value}) {
    if (_exerciseLog == null) return;
    Provider.of<ExerciseLogController>(context, listen: false)
        .updateExerciseLogNotes(
            exerciseLogId: _currentExerciseLog.id, value: value);
  }

  void _loadControllers() {
    if (_exerciseLog == null) return;
    _clearControllers();

    final exerciseLog =
        Provider.of<ExerciseLogController>(context, listen: false)
            .whereExerciseLog(exerciseId: _currentExerciseLog.exercise.id);

    if (exerciseLog == null) return;
    final sets = exerciseLog.sets;

    if (withDurationOnly(type: exerciseLog.exercise.type)) {
      _loadDurationControllers(sets: sets);
    }
    if (withWeightsOnly(type: exerciseLog.exercise.type)) {
      _loadWeightAndRepsControllers(sets: sets);
    }
    if (withRepsOnly(type: exerciseLog.exercise.type)) {
      _loadRepsControllers(sets: sets);
    }
  }

  void _clearControllers() {
    if (_exerciseLog == null) return;
    final exerciseLog = _currentExerciseLog;

    if (withDurationOnly(type: exerciseLog.exercise.type)) {
      _durationControllers = [];
    }
    if (withWeightsOnly(type: exerciseLog.exercise.type)) {
      _weightAndRepsControllers = [];
    }
    if (withRepsOnly(type: exerciseLog.exercise.type)) {
      _repsControllers = [];
    }

    _errors.clear();
  }

  void _disposeControllers() {
    if (_exerciseLog == null) return;
    final exerciseLog = _currentExerciseLog;

    if (withWeightsOnly(type: exerciseLog.exercise.type)) {
      for (final controllerPair in _weightAndRepsControllers) {
        controllerPair.$1.dispose();
        controllerPair.$2.dispose();
      }
    }
    if (withRepsOnly(type: exerciseLog.exercise.type)) {
      for (final controller in _repsControllers) {
        controller.dispose();
      }
    }
  }

  void _addSet() {
    if (_exerciseLog == null) return;
    final pastSets = Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false)
        .whereRecentSetsForExercise(exercise: _currentExerciseLog.exercise);
    Provider.of<ExerciseLogController>(context, listen: false)
        .addSet(exerciseLogId: _currentExerciseLog.id, pastSets: pastSets);
    _loadControllers();
  }

  void _removeSet({required int index}) {
    if (_exerciseLog == null) return;
    Provider.of<ExerciseLogController>(context, listen: false)
        .removeSetForExerciseLog(
            exerciseLogId: _currentExerciseLog.id, index: index);
    _loadControllers();
  }

  void _updateWeight(
      {required int index, required double weight, required SetDto setDto}) {
    if (_exerciseLog == null) return;
    final previousSets = Provider.of<SupabaseExerciseAndRoutineController>(
            context,
            listen: false)
        .wherePrevSetsForExercise(exercise: _currentExerciseLog.exercise);

    final previousWeights =
        previousSets.map((set) => (set as WeightAndRepsSetDto).weight).toList();

    final isOutSideOfRange = isOutsideReasonableRange(previousWeights, weight);
    if (isOutSideOfRange) {
      final message = _getWeightErrorMessage(weight: weight);
      _setError(idx: index, msg: message);
    } else {
      _errors.remove(index);
    }

    _checkWeightRange(weight: weight, index: index);

    final updatedSet = (setDto as WeightAndRepsSetDto).copyWith(weight: weight);
    Provider.of<ExerciseLogController>(context, listen: false).updateWeight(
        exerciseLogId: _currentExerciseLog.id,
        index: index,
        setDto: updatedSet);
  }

  void _updateReps(
      {required int index, required int reps, required SetDto setDto}) {
    if (_exerciseLog == null) return;
    final previousSets = Provider.of<SupabaseExerciseAndRoutineController>(
            context,
            listen: false)
        .wherePrevSetsForExercise(exercise: _currentExerciseLog.exercise);

    final previousReps = previousSets
        .map((set) => switch (_currentExerciseLog.exercise.type) {
              ExerciseType.weights => (set as WeightAndRepsSetDto).reps,
              ExerciseType.bodyWeight => (set as RepsSetDto).reps,
              ExerciseType.duration => throw UnimplementedError(),
            })
        .toList();

    final isOutSideOfRange = isOutsideReasonableRange(previousReps, reps);

    if (isOutSideOfRange) {
      final message = _repsErrorMessage(reps: reps);
      _setError(idx: index, msg: message);
    } else {
      _errors.remove(index);
    }

    _checkRepsRange(reps: reps, index: index);

    final updatedSet = setDto is WeightAndRepsSetDto
        ? setDto.copyWith(reps: reps)
        : (setDto as RepsSetDto).copyWith(reps: reps);
    Provider.of<ExerciseLogController>(context, listen: false).updateReps(
        exerciseLogId: _currentExerciseLog.id,
        index: index,
        setDto: updatedSet);
  }

  void _updateDuration(
      {required int index,
      required Duration duration,
      required SetDto setDto,
      required bool shouldCheck}) {
    if (_exerciseLog == null) return;
    SetDto updatedSet = (setDto as DurationSetDto)
        .copyWith(duration: duration, checked: shouldCheck);
    Provider.of<ExerciseLogController>(context, listen: false).updateDuration(
        exerciseLogId: _currentExerciseLog.id,
        index: index,
        setDto: updatedSet,
        notify: true);
  }

  void _updateSetCheck({required int index}) async {
    if (_exerciseLog == null) return;
    // 1. Pull the current version from provider, not from the parameter
    final exerciseLog =
        Provider.of<ExerciseLogController>(context, listen: false)
            .whereExerciseLog(exerciseId: _currentExerciseLog.exercise.id);

    if (exerciseLog == null || index >= exerciseLog.sets.length) return;
    final currentSet = exerciseLog.sets[index];

    if (currentSet.isEmpty()) {
      showSnackbar(
          context: context,
          message:
              "Mind taking a look at the set values and confirming they're correct?");
      return;
    }

    final checked = !currentSet.checked;

    // Vibrate when logging a set
    if (checked) {
      HapticFeedback.mediumImpact();
    }

    final updatedSet = currentSet.copyWith(checked: checked);
    Provider.of<ExerciseLogController>(context, listen: false).updateSetCheck(
        exerciseLogId: _currentExerciseLog.id,
        index: index,
        setDto: updatedSet);

    _loadControllers();

    // After successfully logging a set in live log mode for a weights or bodyweight exercise,
    // optionally prompt the user about progression if they've been stalled.
    final exerciseType = _currentExerciseLog.exercise.type;
    final isLogMode = widget.editorType == RoutineEditorMode.log;
    if (checked &&
        isLogMode &&
        withReps(type: exerciseType) &&
        !_hasShownProgressionPrompt) {
      _maybeShowProgressionPrompt();
    }
  }

  Future<void> _maybeShowProgressionPrompt() async {
    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);

    final recentLogs = controller.whereRecentExerciseLogsForExercise(
      exercise: _currentExerciseLog.exercise,
      limit: 6,
    );

    final exerciseType = _currentExerciseLog.exercise.type;
    final stalledCount = exerciseType == ExerciseType.weights
        ? getStalledSessionsCountAtSameWeightAndReps(recentLogs: recentLogs)
        : getStalledSessionsCountAtSameReps(recentLogs: recentLogs);

    // Only show reminder at multiples of 5 (5, 10, 15, 20, etc.)
    if (stalledCount == 0 || stalledCount % 5 != 0) return;

    _hasShownProgressionPrompt = true;

    if (!mounted) return;

    final exerciseName = _currentExerciseLog.exercise.name;
    String messageText;

    if (exerciseType == ExerciseType.weights) {
      final stalledSample = recentLogs
          .expand((log) => log.sets)
          .where((s) => s.type == ExerciseType.weights)
          .map((s) => s as WeightAndRepsSetDto)
          .where((s) => s.weight > 0 && s.reps > 0)
          .toList()
          .lastOrNull;

      final weightText =
          stalledSample != null ? "${stalledSample.weight} kg" : "this weight";
      final repsText =
          stalledSample != null ? "${stalledSample.reps} reps" : "this rep range";

      messageText =
          "You've been consistently logging $weightText for $repsText over your recent sessions. "
          "You might be ready to increase the weight slightly, or tighten your target rep range.";
    } else {
      // Bodyweight exercise
      final stalledSample = recentLogs
          .expand((log) => log.sets)
          .where((s) => s.type == ExerciseType.bodyWeight)
          .map((s) => s as RepsSetDto)
          .where((s) => s.reps > 0)
          .toList()
          .lastOrNull;

      final repsText =
          stalledSample != null ? "${stalledSample.reps} reps" : "this rep range";

      messageText =
          "You've been consistently logging $repsText over your recent sessions. "
          "You might be ready to increase the reps, add more sets, or try a more challenging variation.";
    }

    if (!mounted) return;

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
              "Ready to progress on $exerciseName?",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              messageText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text("Got it"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _onLogDurationSet() {
    if (_exerciseLog == null) return;
    final stopwatchState = _durationStopwatchKey.currentState;
    if (stopwatchState != null &&
        stopwatchState.currentDuration.inSeconds > 0) {
      // Store the duration before resetting
      final duration = stopwatchState.currentDuration;

      // Add a new set
      _addSet();

      // Wait for the widget to rebuild with the new set, then update it
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _exerciseLog != null) {
          final exerciseLog = Provider.of<ExerciseLogController>(context,
                  listen: false)
              .whereExerciseLog(exerciseId: _currentExerciseLog.exercise.id);
          if (exerciseLog == null) return;
          final sets = exerciseLog.sets;

          if (sets.isNotEmpty) {
            // Get the newly added set index (last one)
            final newSetIndex = sets.length - 1;
            final setDto = sets[newSetIndex] as DurationSetDto;

            // Update its duration and auto-check it
            final updatedSet =
                setDto.copyWith(duration: duration, checked: true);

            // Vibrate when logging a duration set
            HapticFeedback.mediumImpact();

            Provider.of<ExerciseLogController>(context, listen: false)
                .updateSetCheck(
                    exerciseLogId: _currentExerciseLog.id,
                    index: newSetIndex,
                    setDto: updatedSet);
          }
        }
      });

      // Reset the stopwatch
      stopwatchState.resetStopwatch();
    }
  }

  void _checkWeightRange({required double weight, required int index}) {
    if (isDefaultWeightUnit()) {
      if (weight < 0.5 || weight > 500) {
        final message = 'Weight must be between 0.5 and 500 kg.';
        _setError(idx: index, msg: message);
      }
    } else {
      if (weight < 1 || weight > 1100) {
        final message = 'Weight must be between 1 and 1100 lbs.';
        _setError(idx: index, msg: message);
      }
    }
  }

  void _checkRepsRange({required int reps, required int index}) {
    if (reps <= 0) {
      final message = 'You need to complete at least 1 repetition.';
      _setError(idx: index, msg: message);
    }
  }

  void _loadWeightAndRepsControllers({required List<SetDto> sets}) {
    if (_exerciseLog == null) return;
    final previousSets = Provider.of<SupabaseExerciseAndRoutineController>(
            context,
            listen: false)
        .wherePrevSetsForExercise(exercise: _currentExerciseLog.exercise);

    final previousWeights =
        previousSets.map((set) => (set as WeightAndRepsSetDto).weight).toList();

    List<(TextEditingController, TextEditingController)> controllers = [];
    for (final (index, set) in sets.indexed) {
      final weight = (set as WeightAndRepsSetDto).weight;
      final reps = set.reps;

      final isOutSideOfRange =
          isOutsideReasonableRange(previousWeights, weight);
      if (isOutSideOfRange) {
        final message = _getWeightErrorMessage(weight: weight);
        _setError(idx: index, msg: message);
      } else {
        _errors.remove(index);
      }

      _checkWeightRange(weight: weight, index: index);

      _checkRepsRange(reps: reps, index: index);

      final weightController = TextEditingController(text: weight.toString());
      final repsController = TextEditingController(text: reps.toString());
      controllers.add((weightController, repsController));
    }
    setState(() {
      _weightAndRepsControllers = controllers;
    });
  }

  void _loadRepsControllers({required List<SetDto> sets}) {
    if (_exerciseLog == null) return;
    final previousSets = Provider.of<SupabaseExerciseAndRoutineController>(
            context,
            listen: false)
        .wherePrevSetsForExercise(exercise: _currentExerciseLog.exercise);

    final previousReps = previousSets
        .map((set) => switch (_currentExerciseLog.exercise.type) {
              ExerciseType.weights => (set as WeightAndRepsSetDto).reps,
              ExerciseType.bodyWeight => (set as RepsSetDto).reps,
              ExerciseType.duration => throw UnimplementedError(),
            })
        .toList();

    List<TextEditingController> controllers = [];
    for (final (index, set) in sets.indexed) {
      final reps = switch (_currentExerciseLog.exercise.type) {
        ExerciseType.weights => (set as WeightAndRepsSetDto).reps,
        ExerciseType.bodyWeight => (set as RepsSetDto).reps,
        ExerciseType.duration => throw UnimplementedError(),
      };
      final isOutSideOfRange = isOutsideReasonableRange(previousReps, reps);
      if (isOutSideOfRange) {
        final message = _repsErrorMessage(reps: reps);
        _setError(idx: index, msg: message);
      } else {
        _errors.remove(index);
      }

      _checkRepsRange(reps: reps, index: index);

      final repsController = TextEditingController(text: reps.toString());
      controllers.add(repsController);
    }
    setState(() {
      _repsControllers = controllers;
    });
  }

  String _repsErrorMessage({required int reps}) =>
      "Hmm, $reps ${pluralize(word: "rep", count: reps)} looks a bit off your usual range. Mind checking the value just to be sure?.";

  String _getWeightErrorMessage({required double weight}) =>
      "Hmm, $weight${weightUnit()} looks a bit off your usual range. Mind checking the value just to be sure?.";

  void _setError({required int idx, required String? msg}) {
    if (msg == null) {
      _errors.remove(idx);
    } else {
      _errors[idx] = msg;
    }
  }

  void _loadDurationControllers({required List<SetDto> sets}) {
    List<DateTime> controllers = [];
    for (final set in sets) {
      final duration = (set as DurationSetDto).duration;
      final startTime = DateTime.now().subtract(duration);
      controllers.add(startTime);
    }
    setState(() {
      _durationControllers = controllers;
    });
  }

  void _updateNotesController(String value) {
    _updateExerciseLogNotes(value: value);
    // Update the controller to reflect changes from external updates
    if (_notesController.text != value) {
      _notesController.text = value;
    }
  }

  @override
  void initState() {
    super.initState();
    _exerciseLog = Provider.of<ExerciseLogController>(context, listen: false)
        .whereExerciseLog(exerciseId: widget.exerciseLogId);

    // If exercise log doesn't exist, return early (widget will show empty state)
    if (_exerciseLog == null) {
      return;
    }

    _notesController = TextEditingController(text: _exerciseLog!.notes);
    _loadControllers();
  }

  @override
  void dispose() {
    _disposeControllers();
    _notesController.dispose();
    _notesFocusNode.dispose();
    super.dispose();
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus(); // Dismisses the keyboard
  }

  void _showWeightCalculator() {
    showAppBottomSheet(
        context: context,
        isScrollControlled: false,
        child: WeightPlateCalculator(
            target: (_selectedSetDto as WeightAndRepsSetDto?)?.weight ?? 0));
  }

  void _onTapWeightEditor({required SetDto setDto}) {
    setState(() {
      _selectedSetDto = setDto;
    });
  }

  void _onTapRepsEditor() {
    setState(() {
      _selectedSetDto = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    // If exercise log doesn't exist, show empty state
    if (_exerciseLog == null) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            gradient: themeGradient(context: context),
          ),
          child: const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Exercise log not found',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
      );
    }

    bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom != 0;

    final exerciseLog = context.select<ExerciseLogController, ExerciseLogDto?>(
        (c) => c.whereExerciseLog(exerciseId: _exerciseLog!.exercise.id));

    // If exercise log was removed, show empty state
    if (exerciseLog == null) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            gradient: themeGradient(context: context),
          ),
          child: const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Exercise log not found',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          ),
        ),
      );
    }

    // Update notes controller if exercise log notes changed externally
    if (_notesController.text != exerciseLog.notes) {
      _notesController.text = exerciseLog.notes;
    }

    final exerciseType = exerciseLog.exercise.type;

    final currentSets = exerciseLog.sets;

    final bool isDurationExercise = exerciseType == ExerciseType.duration;
    final bool isLogMode = widget.editorType == RoutineEditorMode.log;
    // We currently only pass showSetCheck = false from the template editor,
    // so treat that as "template mode" to tweak duration behaviour.
    final bool isTemplateMode = !widget.showSetCheck;

    hasEmptyValues(sets: currentSets, exerciseType: exerciseType);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Stack(
        children: [
          Column(
            children: [
              // Custom header with sapphire background
              Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 16, 12),
                decoration: const BoxDecoration(
                  color: sapphireDark80,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(MaterialPageRoute(
                              builder: (context) => ExerciseHomeScreen(
                                  exercise: exerciseLog.exercise)));
                        },
                        child: Text(
                          exerciseLog.exercise.name,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                        ),
                      ),
                    ),
                    // Only allow manual "add set" for:
                    // - non-duration exercises, or
                    // - duration exercises when editing a past log (not live log, not template)
                    if (!isDurationExercise || (!isLogMode && !isTemplateMode))
                      IconButton(
                        onPressed: _addSet,
                        icon: const FaIcon(
                          FontAwesomeIcons.circlePlus,
                          size: 22,
                          color: Colors.white,
                        ),
                        tooltip: 'Add new set',
                      ),
                  ],
                ),
              ),
              // Content
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: themeGradient(context: context),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.only(
                      // Leave enough space so notes aren't hidden behind the FAB overlay,
                      // while still letting the list visually reach the bottom of the sheet.
                      bottom: 80 + MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            spacing: 20,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Stopwatch UI for duration exercises in log mode
                              if (exerciseType == ExerciseType.duration &&
                                  widget.editorType == RoutineEditorMode.log)
                                DurationStopwatchWidget(
                                  key: _durationStopwatchKey,
                                  onLogSet: _onLogDurationSet,
                                ),
                              // For duration exercises in the template editor, we
                              // don't allow pre-configuring sets. Instead, show a
                              // simple hint that this will be captured in real time
                              // during logging.
                              if (isDurationExercise && isTemplateMode)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "This time-based exercise will be tracked with a timer during your workout.",
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                            color: Colors.white70,
                                          ),
                                    ),
                                  ],
                                )
                              else ...[
                                if (currentSets.isEmpty &&
                                    withReps(type: exerciseType))
                                  Column(
                                    children: [
                                      const SizedBox(height: 10),
                                      NoListEmptyState(
                                        message:
                                            "Tap the + button to start adding sets to your exercise",
                                      ),
                                    ],
                                  ),
                                switch (exerciseType) {
                                  ExerciseType.weights =>
                                    _WeightAndRepsSetListView(
                                      sets: currentSets
                                          .map((set) =>
                                              set as WeightAndRepsSetDto)
                                          .toList(),
                                      updateSetCheck: _updateSetCheck,
                                      removeSet: _removeSet,
                                      updateReps: _updateReps,
                                      updateWeight: _updateWeight,
                                      controllers: _weightAndRepsControllers,
                                      onTapWeightEditor: _onTapWeightEditor,
                                      onTapRepsEditor: _onTapRepsEditor,
                                      editorType: widget.editorType,
                                      showSetCheck: widget.showSetCheck,
                                    ),
                                  ExerciseType.bodyWeight => _RepsSetListView(
                                      sets: currentSets
                                          .map((set) => set as RepsSetDto)
                                          .toList(),
                                      updateSetCheck: _updateSetCheck,
                                      removeSet: _removeSet,
                                      updateReps: _updateReps,
                                      controllers: _repsControllers,
                                      onTapRepsEditor: _onTapRepsEditor,
                                      editorType: widget.editorType,
                                      showSetCheck: widget.showSetCheck,
                                    ),
                                  ExerciseType.duration => _DurationSetListView(
                                      sets: currentSets
                                          .map((set) => set as DurationSetDto)
                                          .toList(),
                                      updateSetCheck: _updateSetCheck,
                                      removeSet: _removeSet,
                                      updateDuration: _updateDuration,
                                      controllers: _durationControllers,
                                      editorType: widget.editorType,
                                      showSetCheck: widget.showSetCheck,
                                    ),
                                },
                              ],
                            ],
                          ),
                        ),
                        // Notes section - always shown
                        Builder(builder: (context) {
                          final isDark =
                              Theme.of(context).brightness == Brightness.dark;
                          final color = isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.06);
                          // Full-bleed divider: cancel out the 16px horizontal padding
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Divider(
                              thickness: 0.5,
                              color: color,
                              height: 16,
                            ),
                          );
                        }),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Notes label
                              Text(
                                'Notes',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white70,
                                    ),
                              ),
                              // Notes input field (no borders)
                              TextField(
                                controller: _notesController,
                                focusNode: _notesFocusNode,
                                cursorColor: Colors.white,
                                onChanged: _updateNotesController,
                                decoration: InputDecoration(
                                  hintText: "Enter notes (optional)",
                                  hintStyle: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.4),
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  filled: false,
                                ),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                maxLines: null,
                                minLines: 4,
                                keyboardType: TextInputType.multiline,
                                textCapitalization:
                                    TextCapitalization.sentences,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          // Floating action buttons overlay
          if (isKeyboardOpen)
            Positioned(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              child: SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    FloatingActionButton(
                      heroTag: UniqueKey(),
                      onPressed: _dismissKeyboard,
                      enableFeedback: true,
                      backgroundColor:
                          themeGradient(context: context).colors.first,
                      elevation: 8.0,
                      child: const FaIcon(Icons.keyboard_hide_rounded),
                    ),
                    if (_selectedSetDto != null)
                      FloatingActionButton(
                        heroTag: UniqueKey(),
                        onPressed: _showWeightCalculator,
                        enableFeedback: true,
                        backgroundColor:
                            themeGradient(context: context).colors.first,
                        elevation: 8.0,
                        child: Image.asset(
                          'icons/dumbbells.png',
                          fit: BoxFit.contain,
                          color: Colors.white,
                          height: 24,
                        ),
                      )
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeightAndRepsSetListView extends StatelessWidget {
  final RoutineEditorMode editorType;
  final bool showSetCheck;
  final List<WeightAndRepsSetDto> sets;
  final List<(TextEditingController, TextEditingController)> controllers;
  final void Function({required int index}) removeSet;
  final void Function({required int index}) updateSetCheck;
  final void Function(
      {required int index,
      required int reps,
      required SetDto setDto}) updateReps;
  final void Function(
      {required int index,
      required double weight,
      required SetDto setDto}) updateWeight;
  final void Function({required SetDto setDto}) onTapWeightEditor;
  final void Function() onTapRepsEditor;

  const _WeightAndRepsSetListView(
      {required this.sets,
      required this.controllers,
      required this.updateSetCheck,
      required this.removeSet,
      required this.updateReps,
      required this.updateWeight,
      required this.onTapWeightEditor,
      required this.onTapRepsEditor,
      required this.editorType,
      required this.showSetCheck});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final setDto = sets[index];
        return WeightsAndRepsSetRow(
          editorType: editorType,
          setDto: setDto,
          showCheck: showSetCheck,
          onCheck: () => updateSetCheck(index: index),
          onRemoved: () => removeSet(index: index),
          onChangedReps: (int value) =>
              updateReps(index: index, reps: value, setDto: setDto),
          onChangedWeight: (double value) =>
              updateWeight(index: index, weight: value, setDto: setDto),
          onTapWeightEditor: () => onTapWeightEditor(setDto: setDto),
          onTapRepsEditor: () => onTapRepsEditor(),
          controllers: controllers[index],
        );
      },
    );
  }
}

class _RepsSetListView extends StatelessWidget {
  final RoutineEditorMode editorType;
  final bool showSetCheck;
  final List<RepsSetDto> sets;
  final List<TextEditingController> controllers;
  final void Function({required int index}) removeSet;
  final void Function({required int index}) updateSetCheck;
  final void Function(
      {required int index,
      required int reps,
      required SetDto setDto}) updateReps;
  final void Function() onTapRepsEditor;

  const _RepsSetListView(
      {required this.sets,
      required this.controllers,
      required this.updateSetCheck,
      required this.removeSet,
      required this.updateReps,
      required this.onTapRepsEditor,
      required this.editorType,
      required this.showSetCheck});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: sets.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, index) {
        final setDto = sets[index];
        return RepsSetRow(
          editorType: editorType,
          setDto: setDto,
          showCheck: showSetCheck,
          onCheck: () => updateSetCheck(index: index),
          onRemoved: () => removeSet(index: index),
          onChangedReps: (int value) =>
              updateReps(index: index, reps: value, setDto: setDto),
          onTapRepsEditor: () => onTapRepsEditor(),
          controller: controllers[index],
        );
      },
    );
  }
}

class _DurationSetListView extends StatelessWidget {
  final RoutineEditorMode editorType;
  final bool showSetCheck;
  final List<DurationSetDto> sets;
  final List<DateTime> controllers;
  final void Function({required int index}) removeSet;
  final void Function({required int index}) updateSetCheck;
  final void Function(
      {required int index,
      required Duration duration,
      required SetDto setDto,
      required bool shouldCheck}) updateDuration;

  const _DurationSetListView(
      {required this.sets,
      required this.controllers,
      required this.updateSetCheck,
      required this.removeSet,
      required this.updateDuration,
      required this.editorType,
      required this.showSetCheck});

  @override
  Widget build(BuildContext context) {
    // Filter to show only completed sets in log mode
    final displaySets = editorType == RoutineEditorMode.log
        ? sets.where((set) => set.checked).toList()
        : sets;

    return Column(
      spacing: 20,
      children: [
        // Sets List
        if (displaySets.isNotEmpty)
          ListView.separated(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displaySets.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, index) {
              final setDto = displaySets[index];
              final actualIndex = sets.indexOf(setDto);
              return DurationSetRow(
                editorType: editorType,
                setDto: setDto,
                onCheck: () => updateSetCheck(index: actualIndex),
                onRemoved: () => removeSet(index: actualIndex),
                startTime:
                    controllers.isNotEmpty && actualIndex < controllers.length
                        ? controllers[actualIndex]
                        : DateTime.now(),
                onUpdateDuration: (Duration duration, bool shouldCheck) =>
                    updateDuration(
                        index: actualIndex,
                        setDto: setDto,
                        duration: duration,
                        shouldCheck: shouldCheck),
              );
            },
          ),
      ],
    );
  }
}
