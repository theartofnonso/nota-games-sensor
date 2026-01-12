import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'package:trainware/colors.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/controllers/exercise_log_controller.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';
import 'package:trainware/dtos/set_dtos/duration_set_dto.dart';
import 'package:trainware/enums/exercise_type_enums.dart';
import 'package:trainware/utils/dialog_utils.dart';
import 'package:trainware/utils/exercise_logs_utils.dart';
import 'package:trainware/utils/lottie_exercise_registry.dart';
import 'package:trainware/utils/sets_utils.dart';
import 'package:trainware/widgets/routine/editors/set_rows/duration_set_row.dart';
import 'package:trainware/widgets/routine/editors/set_rows/reps_set_row.dart';
import 'package:trainware/widgets/routine/editors/set_rows/weights_and_reps_set_row.dart';

import '../../../dtos/appsync/exercise_dto.dart';
import '../../../dtos/set_dtos/reps_dto.dart';
import '../../../dtos/set_dtos/set_dto.dart';
import '../../../dtos/set_dtos/weight_and_reps_dto.dart';
import '../../../enums/routine_editor_type_enums.dart';
import '../../../utils/general_utils.dart';
import '../../../utils/navigation_utils.dart';
import '../../../utils/routine_editors_utils.dart';
import '../../../widgets/list_tile.dart';
import '../../bottom_sheets/app_bottom_sheet.dart';
import '../../buttons/opacity_button_widget_two.dart';
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
    final type = _currentExerciseLog.exercise.type;
    if (type == ExerciseType.none) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Pick an exercise type before adding sets.'),
      ));
      return;
    }
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
    final updatedSet = (setDto as WeightAndRepsSetDto).copyWith(weight: weight);
    Provider.of<ExerciseLogController>(context, listen: false).updateWeight(
        exerciseLogId: _currentExerciseLog.id,
        index: index,
        setDto: updatedSet);
  }

  void _updateReps(
      {required int index, required int reps, required SetDto setDto}) {
    if (_exerciseLog == null) return;
    final updatedSet = setDto is WeightAndRepsSetDto
        ? setDto.copyWith(reps: reps)
        : setDto is RepsSetDto
            ? setDto.copyWith(reps: reps)
            : setDto;
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

      final weightText = stalledSample != null
          ? "${weightWithConversion(value: stalledSample.weight)} ${weightUnit()}"
          : "this weight";
      final repsText = stalledSample != null
          ? "${stalledSample.reps} reps"
          : "this rep range";

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

      final repsText = stalledSample != null
          ? "${stalledSample.reps} reps"
          : "this rep range";

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

  void _loadWeightAndRepsControllers({required List<SetDto> sets}) {
    if (_exerciseLog == null) return;
    final weightSets = sets.whereType<WeightAndRepsSetDto>().toList();
    List<(TextEditingController, TextEditingController)> controllers = [];
    for (final set in weightSets) {
      final weight = set.weight;
      final reps = set.reps;

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
    // Only reps-based sets for bodyweight exercises.
    final repsSets = sets.whereType<RepsSetDto>().toList();
    List<TextEditingController> controllers = [];
    for (final set in repsSets) {
      final reps = set.reps;
      final repsController = TextEditingController(text: reps.toString());
      controllers.add(repsController);
    }
    setState(() {
      _repsControllers = controllers;
    });
  }

  void _loadDurationControllers({required List<SetDto> sets}) {
    final durationSets = sets.whereType<DurationSetDto>().toList();
    List<DateTime> controllers = [];
    for (final set in durationSets) {
      final duration = set.duration;
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
    // Get the current weight from the text field controller if available
    double targetWeight = 0;

    if (_selectedSetDto != null && _selectedSetDto is WeightAndRepsSetDto) {
      final selectedSet = _selectedSetDto as WeightAndRepsSetDto;
      final weightSets =
          _currentExerciseLog.sets.whereType<WeightAndRepsSetDto>().toList();

      // Find the index of the selected set
      final setIndex = weightSets.indexWhere((s) => s == selectedSet);

      if (setIndex >= 0 && setIndex < _weightAndRepsControllers.length) {
        // Get the weight controller for this set
        final weightController = _weightAndRepsControllers[setIndex].$1;
        final weightText = weightController.text.trim();

        // Parse the weight from the text field
        final parsedWeight = double.tryParse(weightText);
        if (parsedWeight != null && parsedWeight > 0) {
          // Convert to kg if using lbs (weight is stored in kg internally)
          targetWeight =
              isDefaultWeightUnit() ? parsedWeight : toKg(parsedWeight);
        } else {
          // Fallback to the set's weight property if text field is empty/invalid
          targetWeight = selectedSet.weight;
        }
      } else {
        // Fallback to the set's weight property if index not found
        targetWeight = selectedSet.weight;
      }
    }

    showAppBottomSheet(
        context: context,
        isScrollControlled: false,
        child: WeightPlateCalculator(target: targetWeight));
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

  void _addAlternativesDirectly() {
    if (!mounted || _exerciseLog == null) return;

    final controller =
        Provider.of<ExerciseLogController>(context, listen: false);
    final allExerciseLogs = controller.exerciseLogs;

    // Build exclude list: current exercise + all exercises in routine + existing alternatives
    // Deduplicate by exercise ID to ensure we don't exclude the same exercise multiple times
    final excludeExercises = <ExerciseDto>[];
    final seenIds = <String>{};

    // Add current exercise
    if (!seenIds.contains(_currentExerciseLog.exercise.id)) {
      excludeExercises.add(_currentExerciseLog.exercise);
      seenIds.add(_currentExerciseLog.exercise.id);
    }

    // Add all exercises in routine
    for (final log in allExerciseLogs) {
      if (!seenIds.contains(log.exercise.id)) {
        excludeExercises.add(log.exercise);
        seenIds.add(log.exercise.id);
      }
    }

    // Add existing alternatives
    for (final alt in _currentExerciseLog.alternatives) {
      if (!seenIds.contains(alt.id)) {
        excludeExercises.add(alt);
        seenIds.add(alt.id);
      }
    }

    showExercisesInLibrary(
      context: context,
      exercisesToExclude: excludeExercises,
      onSelected: (List<ExerciseDto> selectedExercises) {
        if (!mounted || _exerciseLog == null) return;
        // Deduplicate by exercise ID to prevent duplicates
        final existingIds =
            _currentExerciseLog.alternatives.map((alt) => alt.id).toSet();
        final uniqueSelected = selectedExercises
            .where((ex) => !existingIds.contains(ex.id))
            .toList();
        final newAlternatives = [
          ..._currentExerciseLog.alternatives,
          ...uniqueSelected,
        ];
        controller.updateExerciseLogAlternatives(
          exerciseLogId: _currentExerciseLog.id,
          alternatives: newAlternatives,
        );
        // Update local state
        setState(() {
          _exerciseLog = controller.whereExerciseLog(
            exerciseId: _currentExerciseLog.exercise.id,
          );
        });
      },
      type: _currentExerciseLog.exercise.type,
    );
  }

  Future<void> _confirmReplaceWithAlternative(ExerciseDto alternative) async {
    if (_exerciseLog == null) return;

    bool shouldReplace = false;

    await showAppBottomSheet(
      context: context,
      isScrollControlled: false,
      isDismissible: true,
      child: Padding(
        padding: const EdgeInsets.all(26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Replace exercise?",
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Replace "${_currentExerciseLog.exercise.name}" with "${alternative.name}"?',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: OpacityButtonWidgetTwo(
                label: 'Replace',
                buttonColor: vibrantGreen,
                showArrowRight: false,
                onPressed: () {
                  Navigator.of(context).pop();
                  shouldReplace = true;
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (!shouldReplace || !mounted) return;

    _replaceWithAlternative(alternative);
  }

  void _replaceWithAlternative(ExerciseDto alternative) {
    if (_exerciseLog == null) return;

    final controller =
        Provider.of<ExerciseLogController>(context, listen: false);
    final supabaseController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);

    // Store the current exercise before replacement
    final oldExercise = _currentExerciseLog.exercise;

    // Get past sets for the alternative exercise
    final pastSets =
        supabaseController.whereRecentSetsForExercise(exercise: alternative);

    // Replace the current exercise with the alternative
    controller.replaceExerciseLog(
      oldExerciseId: _currentExerciseLog.exercise.id,
      newExercise: alternative,
      pastSets: pastSets,
    );

    // Update alternatives list:
    // 1. Remove the selected alternative (since it's now the main exercise)
    // 2. Add the old exercise to the alternatives list
    final updatedAlternatives = _currentExerciseLog.alternatives
        .where((alt) =>
            alt.id != alternative.id) // Remove the selected alternative
        .toList();

    // Add the old exercise to alternatives if it's not already there
    if (!updatedAlternatives.any((alt) => alt.id == oldExercise.id)) {
      updatedAlternatives.add(oldExercise);
    }

    // Update the alternatives list for the new exercise log
    final newExerciseLog =
        controller.whereExerciseLog(exerciseId: alternative.id);
    if (newExerciseLog != null) {
      controller.updateExerciseLogAlternatives(
        exerciseLogId: newExerciseLog.id,
        alternatives: updatedAlternatives,
      );
    }

    // Update state to reflect the change
    setState(() {
      _exerciseLog = controller.whereExerciseLog(exerciseId: alternative.id);
      if (_exerciseLog != null) {
        _loadControllers();
        // Update notes controller if needed
        _notesController.text = _exerciseLog!.notes;
      }
    });
  }

  Future<void> _confirmRemoveAlternativeFromCard(
      ExerciseDto alternative) async {
    if (_exerciseLog == null) return;

    final shouldRemove = await confirmRemoveExerciseBottomSheet(
      context: context,
      exerciseName: alternative.name,
      fromLabel: 'alternatives',
    );

    if (!shouldRemove || !mounted) return;

    final controller =
        Provider.of<ExerciseLogController>(context, listen: false);
    final newAlternatives = _currentExerciseLog.alternatives
        .where((alt) => alt.id != alternative.id)
        .toList();

    controller.updateExerciseLogAlternatives(
      exerciseLogId: _currentExerciseLog.id,
      alternatives: newAlternatives,
    );

    // Update local state
    setState(() {
      _exerciseLog = controller.whereExerciseLog(
        exerciseId: _currentExerciseLog.exercise.id,
      );
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

    // Update _exerciseLog reference
    _exerciseLog = exerciseLog;

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
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: exerciseLog.exercise.isSystem
                          ? FutureBuilder<String?>(
                              future: LottieExerciseRegistry.lottieFor(
                                  exerciseLog.exercise.id),
                              builder: (context, snapshot) {
                                final asset = snapshot.data;
                                if (asset != null) {
                                  return Lottie.asset(
                                    asset,
                                    fit: BoxFit.contain,
                                    repeat: true,
                                  );
                                }
                                return const FaIcon(
                                  FontAwesomeIcons.ban,
                                  size: 28,
                                  color: Color.fromRGBO(255, 255, 255, 0.4),
                                );
                              },
                            )
                          : const FaIcon(
                              FontAwesomeIcons.ban,
                              size: 28,
                              color: Color.fromRGBO(255, 255, 255, 0.4),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          navigateToExerciseHome(
                              context: context, exercise: exerciseLog.exercise);
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
                                // Compute typed sets per exercise type
                                if (exerciseType == ExerciseType.weights) ...[
                                  _WeightAndRepsSetListView(
                                    sets: currentSets
                                        .whereType<WeightAndRepsSetDto>()
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
                                  if (currentSets
                                      .whereType<WeightAndRepsSetDto>()
                                      .isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: NoListEmptyState(
                                        message:
                                            "Tap the + button to start adding sets to your exercise",
                                      ),
                                    ),
                                ] else if (exerciseType ==
                                    ExerciseType.bodyWeight) ...[
                                  _RepsSetListView(
                                    sets: currentSets
                                        .whereType<RepsSetDto>()
                                        .toList(),
                                    updateSetCheck: _updateSetCheck,
                                    removeSet: _removeSet,
                                    updateReps: _updateReps,
                                    controllers: _repsControllers,
                                    onTapRepsEditor: _onTapRepsEditor,
                                    editorType: widget.editorType,
                                    showSetCheck: widget.showSetCheck,
                                  ),
                                  if (currentSets
                                      .whereType<RepsSetDto>()
                                      .isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: NoListEmptyState(
                                        message:
                                            "Tap the + button to start adding sets to your exercise",
                                      ),
                                    ),
                                ] else if (exerciseType ==
                                    ExerciseType.duration) ...[
                                  _DurationSetListView(
                                    sets: currentSets
                                        .whereType<DurationSetDto>()
                                        .toList(),
                                    updateSetCheck: _updateSetCheck,
                                    removeSet: _removeSet,
                                    updateDuration: _updateDuration,
                                    controllers: _durationControllers,
                                    editorType: widget.editorType,
                                    showSetCheck: widget.showSetCheck,
                                  ),
                                  if (currentSets
                                      .whereType<DurationSetDto>()
                                      .isEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: NoListEmptyState(
                                        message:
                                            "Tap the + button to start adding sets to your exercise",
                                      ),
                                    ),
                                ] else
                                  const SizedBox.shrink(),
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
                        // Alternatives section - always show in template mode and live log mode
                        if (isTemplateMode ||
                            (isLogMode && widget.showSetCheck)) ...[
                          Builder(builder: (context) {
                            final isDark =
                                Theme.of(context).brightness == Brightness.dark;
                            final color = isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : Colors.black.withValues(alpha: 0.06);
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
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16),
                                  child: Text(
                                    'Alternative Exercises',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white70,
                                        ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  height: 80,
                                  child: exerciseLog.alternatives.isEmpty
                                      ? Center(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 16),
                                            child: Row(
                                              children: [
                                                GestureDetector(
                                                  onTap:
                                                      _addAlternativesDirectly,
                                                  child: Container(
                                                    width: 64,
                                                    height: 64,
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              12),
                                                      border: Border.all(
                                                        color: Colors.white
                                                            .withValues(
                                                                alpha: 0.2),
                                                        width: 1.5,
                                                      ),
                                                    ),
                                                    child: const Center(
                                                      child: FaIcon(
                                                        FontAwesomeIcons
                                                            .circlePlus,
                                                        size: 24,
                                                        color: Colors.white70,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Expanded(
                                                  child: Text(
                                                    'Tap + to add alternative exercises',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: Colors.white54,
                                                        ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          padding: EdgeInsets.zero,
                                          itemCount:
                                              exerciseLog.alternatives.length +
                                                  1, // +1 for add button
                                          itemBuilder: (context, index) {
                                            if (index == 0) {
                                              // Add button as first item
                                              return _AlternativeExerciseCard(
                                                exercise:
                                                    null, // null indicates add button
                                                isFirst: true,
                                                isLast: false,
                                                onTap: _addAlternativesDirectly,
                                              );
                                            }
                                            final alternative = exerciseLog
                                                .alternatives[index - 1];
                                            return _AlternativeExerciseCard(
                                              exercise: alternative,
                                              isFirst: false,
                                              isLast: index ==
                                                  exerciseLog
                                                      .alternatives.length,
                                              onTap: () =>
                                                  _confirmReplaceWithAlternative(
                                                      alternative),
                                              onLongPress: () =>
                                                  _confirmRemoveAlternativeFromCard(
                                                      alternative),
                                            );
                                          },
                                        ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

class _AlternativesManagementWidget extends StatefulWidget {
  final ExerciseLogDto exerciseLog;

  const _AlternativesManagementWidget({
    required this.exerciseLog,
  });

  @override
  State<_AlternativesManagementWidget> createState() =>
      _AlternativesManagementWidgetState();
}

class _AlternativesManagementWidgetState
    extends State<_AlternativesManagementWidget> {
  late ExerciseLogDto _currentExerciseLog;

  @override
  void initState() {
    super.initState();
    _currentExerciseLog = widget.exerciseLog;
  }

  void _updateAlternatives(List<ExerciseDto> alternatives) {
    final controller =
        Provider.of<ExerciseLogController>(context, listen: false);
    final updatedLog = _currentExerciseLog.copyWith(alternatives: alternatives);
    controller.updateExerciseLogAlternatives(
      exerciseLogId: _currentExerciseLog.id,
      alternatives: alternatives,
    );
    setState(() {
      _currentExerciseLog = updatedLog;
    });
  }

  void _addAlternatives() async {
    final controller =
        Provider.of<ExerciseLogController>(context, listen: false);
    final allExerciseLogs = controller.exerciseLogs;
    final excludeExercises = [
      _currentExerciseLog.exercise,
      ...allExerciseLogs.map((log) => log.exercise),
      ..._currentExerciseLog.alternatives,
    ].toList();

    showExercisesInLibrary(
      context: context,
      exercisesToExclude: excludeExercises,
      onSelected: (List<ExerciseDto> selectedExercises) {
        // Deduplicate by exercise ID to prevent duplicates
        final existingIds =
            _currentExerciseLog.alternatives.map((alt) => alt.id).toSet();
        final uniqueSelected = selectedExercises
            .where((ex) => !existingIds.contains(ex.id))
            .toList();
        final newAlternatives = [
          ..._currentExerciseLog.alternatives,
          ...uniqueSelected,
        ];
        _updateAlternatives(newAlternatives);
      },
      type: _currentExerciseLog.exercise.type,
    );
  }

  Future<bool> _confirmRemoveAlternative(ExerciseDto alternative) async {
    return confirmRemoveExerciseBottomSheet(
      context: context,
      exerciseName: alternative.name,
      fromLabel: 'alternatives',
    );
  }

  void _removeAlternative(ExerciseDto alternative) {
    final newAlternatives = _currentExerciseLog.alternatives
        .where((alt) => alt.id != alternative.id)
        .toList();
    _updateAlternatives(newAlternatives);
  }

  @override
  Widget build(BuildContext context) {
    final alternatives = _currentExerciseLog.alternatives;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Alternative Exercises",
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              IconButton(
                onPressed: _addAlternatives,
                icon: const FaIcon(
                  FontAwesomeIcons.circlePlus,
                  size: 22,
                ),
                tooltip: 'Add alternative',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: alternatives.isEmpty
                ? NoListEmptyState(
                    message:
                        "No alternative exercises added yet.\nTap the + button to add alternative exercises for this exercise",
                  )
                : ListView.separated(
                    itemCount: alternatives.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final alternative = alternatives[index];
                      return Dismissible(
                        key: ValueKey(alternative.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) =>
                            _confirmRemoveAlternative(alternative),
                        onDismissed: (_) {
                          _removeAlternative(alternative);
                        },
                        background: const SizedBox.shrink(),
                        child: _AlternativeExerciseListItem(
                          exercise: alternative,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _AlternativeExerciseCard extends StatelessWidget {
  final ExerciseDto? exercise; // null means it's the add button
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _AlternativeExerciseCard({
    this.exercise,
    this.isFirst = false,
    this.isLast = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: 80,
        height: 80,
        margin: EdgeInsets.only(
          left: isFirst ? 16 : 4,
          right: isLast ? 16 : 4,
        ),
        decoration: exercise != null
            ? BoxDecoration(
                color: sapphireDark80,
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        padding: const EdgeInsets.all(8),
        child: Stack(
          children: [
            Center(
              child: exercise == null
                  ? // Add button
                  const Center(
                      child: FaIcon(
                        FontAwesomeIcons.circlePlus,
                        size: 24,
                        color: Colors.white70,
                      ),
                    )
                  : exercise!.isSystem
                      ? FutureBuilder<String?>(
                          future:
                              LottieExerciseRegistry.lottieFor(exercise!.id),
                          builder: (context, snapshot) {
                            final asset = snapshot.data;
                            if (asset != null) {
                              return SizedBox(
                                width: 56,
                                height: 56,
                                child: Lottie.asset(
                                  asset,
                                  fit: BoxFit.contain,
                                  repeat: true,
                                ),
                              );
                            }
                            // System exercise without lottie - show truncated name
                            return Padding(
                              padding: const EdgeInsets.all(4),
                              child: Text(
                                exercise!.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                              ),
                            );
                          },
                        )
                      : // Custom exercise - show truncated name
                      Padding(
                          padding: const EdgeInsets.all(4),
                          child: Text(
                            exercise!.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white70,
                                      fontSize: 10,
                                    ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlternativeExerciseListItem extends StatelessWidget {
  final ExerciseDto exercise;

  const _AlternativeExerciseListItem({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final isSystem = exercise.isSystem;
    const banColor = Color.fromRGBO(255, 255, 255, 0.4);

    return ThemeListTile(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
        title: Text(
          exercise.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
        ),
        trailing: SizedBox(
          width: 48,
          height: 48,
          child: isSystem
              ? FutureBuilder<String?>(
                  future: LottieExerciseRegistry.lottieFor(exercise.id),
                  builder: (context, snapshot) {
                    final asset = snapshot.data;
                    if (asset != null) {
                      return Lottie.asset(
                        asset,
                        height: 44,
                        fit: BoxFit.contain,
                        repeat: true,
                      );
                    }
                    return const FaIcon(
                      FontAwesomeIcons.ban,
                      size: 26,
                      color: banColor,
                    );
                  },
                )
              : const FaIcon(
                  FontAwesomeIcons.ban,
                  size: 26,
                  color: banColor,
                ),
        ),
      ),
    );
  }
}
