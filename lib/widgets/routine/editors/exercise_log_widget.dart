import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tracker_app/colors.dart';
import 'package:tracker_app/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:tracker_app/controllers/exercise_log_controller.dart';
import 'package:tracker_app/dtos/exercise_log_dto.dart';
import 'package:tracker_app/dtos/set_dtos/duration_set_dto.dart';
import 'package:tracker_app/enums/exercise_type_enums.dart';
import 'package:tracker_app/utils/dialog_utils.dart';
import 'package:tracker_app/utils/exercise_logs_utils.dart';
import 'package:tracker_app/utils/sets_utils.dart';
import 'package:tracker_app/utils/string_utils.dart';
import 'package:tracker_app/widgets/routine/editors/set_headers/duration_set_header.dart';
import 'package:tracker_app/widgets/routine/editors/set_headers/reps_set_header.dart';
import 'package:tracker_app/widgets/routine/editors/set_headers/weight_and_reps_set_header.dart';
import 'package:tracker_app/widgets/routine/editors/set_rows/duration_set_row.dart';
import 'package:tracker_app/widgets/routine/editors/set_rows/reps_set_row.dart';
import 'package:tracker_app/widgets/routine/editors/set_rows/weights_and_reps_set_row.dart';

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
  final ExerciseLogDto? superSet;

  const ExerciseLogWidget(
      {super.key,
      this.editorType = RoutineEditorMode.edit,
      required this.exerciseLogId,
      this.superSet});

  @override
  State<ExerciseLogWidget> createState() => _ExerciseLogWidgetState();
}

class _ExerciseLogWidgetState extends State<ExerciseLogWidget> {
  late ExerciseLogDto _exerciseLog;

  List<(TextEditingController, TextEditingController)>
      _weightAndRepsControllers = [];
  List<TextEditingController> _repsControllers = [];
  List<DateTime> _durationControllers = [];

  bool _showNotes = false;

  SetDto? _selectedSetDto;

  final GlobalKey<DurationStopwatchWidgetState> _durationStopwatchKey =
      GlobalKey();

  final _selectedSetIndex = ValueNotifier<int>(0);

  final _errors = <int, String>{};

  void _updateExerciseLogNotes({required String value}) {
    Provider.of<ExerciseLogController>(context, listen: false)
        .updateExerciseLogNotes(exerciseLogId: _exerciseLog.id, value: value);
  }

  void _loadControllers() {
    _clearControllers();

    final exerciseLog =
        Provider.of<ExerciseLogController>(context, listen: false)
            .whereExerciseLog(exerciseId: _exerciseLog.exercise.id);

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
    final exerciseLog = _exerciseLog;

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
    final exerciseLog = _exerciseLog;

    if (withDurationOnly(type: exerciseLog.exercise.type)) {
      // Duration does not have any controller to dispose
    }
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
    final pastSets = Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false)
        .whereRecentSetsForExercise(exercise: _exerciseLog.exercise);
    Provider.of<ExerciseLogController>(context, listen: false)
        .addSet(exerciseLogId: _exerciseLog.id, pastSets: pastSets);
    _loadControllers();
  }

  void _removeSet({required int index}) {
    Provider.of<ExerciseLogController>(context, listen: false)
        .removeSetForExerciseLog(exerciseLogId: _exerciseLog.id, index: index);
    _loadControllers();
  }

  void _updateWeight(
      {required int index, required double weight, required SetDto setDto}) {
    final previousSets = Provider.of<SupabaseExerciseAndRoutineController>(
            context,
            listen: false)
        .wherePrevSetsForExercise(exercise: _exerciseLog.exercise);

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
        exerciseLogId: _exerciseLog.id, index: index, setDto: updatedSet);
  }

  void _updateReps(
      {required int index, required int reps, required SetDto setDto}) {
    final previousSets = Provider.of<SupabaseExerciseAndRoutineController>(
            context,
            listen: false)
        .wherePrevSetsForExercise(exercise: _exerciseLog.exercise);

    final previousReps = previousSets
        .map((set) => switch (_exerciseLog.exercise.type) {
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
        exerciseLogId: _exerciseLog.id, index: index, setDto: updatedSet);
  }

  void _updateDuration(
      {required int index,
      required Duration duration,
      required SetDto setDto,
      required bool shouldCheck}) {
    SetDto updatedSet = (setDto as DurationSetDto)
        .copyWith(duration: duration, checked: shouldCheck);
    Provider.of<ExerciseLogController>(context, listen: false).updateDuration(
        exerciseLogId: _exerciseLog.id,
        index: index,
        setDto: updatedSet,
        notify: true);
  }

  void _updateSetCheck({required int index}) async {
    // 1. Pull the current version from provider, not from the parameter
    final currentSet =
        Provider.of<ExerciseLogController>(context, listen: false)
            .whereExerciseLog(exerciseId: _exerciseLog.id)
            .sets[index];

    if (currentSet.isEmpty()) {
      showSnackbar(
          context: context,
          message:
              "Mind taking a look at the set values and confirming they’re correct?");
      return;
    }

    final checked = !currentSet.checked;
    final updatedSet = currentSet.copyWith(checked: checked);
    Provider.of<ExerciseLogController>(context, listen: false).updateSetCheck(
        exerciseLogId: _exerciseLog.id, index: index, setDto: updatedSet);

    _loadControllers();
  }

  void _onLogDurationSet() {
    final stopwatchState = _durationStopwatchKey.currentState;
    if (stopwatchState != null &&
        stopwatchState.currentDuration.inSeconds > 0) {
      // Store the duration before resetting
      final duration = stopwatchState.currentDuration;

      // Add a new set
      _addSet();

      // Wait for the widget to rebuild with the new set, then update it
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final exerciseLog =
              Provider.of<ExerciseLogController>(context, listen: false)
                  .whereExerciseLog(exerciseId: _exerciseLog.exercise.id);
          final sets = exerciseLog.sets;

          if (sets.isNotEmpty) {
            // Get the newly added set index (last one)
            final newSetIndex = sets.length - 1;
            final setDto = sets[newSetIndex] as DurationSetDto;

            // Update its duration and auto-check it
            final updatedSet =
                setDto.copyWith(duration: duration, checked: true);
            Provider.of<ExerciseLogController>(context, listen: false)
                .updateSetCheck(
                    exerciseLogId: _exerciseLog.id,
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
    final previousSets = Provider.of<SupabaseExerciseAndRoutineController>(
            context,
            listen: false)
        .wherePrevSetsForExercise(exercise: _exerciseLog.exercise);

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
    final previousSets = Provider.of<SupabaseExerciseAndRoutineController>(
            context,
            listen: false)
        .wherePrevSetsForExercise(exercise: _exerciseLog.exercise);

    final previousReps = previousSets
        .map((set) => switch (_exerciseLog.exercise.type) {
              ExerciseType.weights => (set as WeightAndRepsSetDto).reps,
              ExerciseType.bodyWeight => (set as RepsSetDto).reps,
              ExerciseType.duration => throw UnimplementedError(),
            })
        .toList();

    List<TextEditingController> controllers = [];
    for (final (index, set) in sets.indexed) {
      final reps = switch (_exerciseLog.exercise.type) {
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

  void _toggleNotes() {
    setState(() {
      _showNotes = !_showNotes;
    });

    showAppBottomSheet(
      context: context,
      isScrollControlled: true,
      child: Builder(
        builder: (context) {
          final currentNotes =
              Provider.of<ExerciseLogController>(context, listen: false)
                  .whereExerciseLog(exerciseId: _exerciseLog.id)
                  .notes;

          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: TextField(
              controller: TextEditingController(text: currentNotes),
              cursorColor: Colors.white,
              onChanged: (value) => _updateExerciseLogNotes(value: value),
              autofocus: true,
              decoration: InputDecoration(
                hintText: "Enter notes",
                contentPadding: EdgeInsets.all(16.0),
                border: InputBorder.none,
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
              ),
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
            ),
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _exerciseLog = Provider.of<ExerciseLogController>(context, listen: false)
        .whereExerciseLog(exerciseId: widget.exerciseLogId);
    _loadControllers();
  }

  @override
  void dispose() {
    _disposeControllers();
    _selectedSetIndex.dispose();
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
    bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom != 0;

    final exerciseLog = context.select<ExerciseLogController, ExerciseLogDto>(
        (c) => c.whereExerciseLog(exerciseId: _exerciseLog.exercise.id));

    final exerciseType = exerciseLog.exercise.type;

    final currentSets = exerciseLog.sets;

    hasEmptyValues(sets: currentSets, exerciseType: exerciseType);

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Stack(
        children: [
          Column(
            children: [
              // Custom header with sapphire background
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: sapphireDark80,
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const FaIcon(FontAwesomeIcons.xmark,
                          size: 20, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 12),
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
                    IconButton(
                      onPressed: _toggleNotes,
                      icon: const FaIcon(FontAwesomeIcons.noteSticky,
                          size: 18, color: Colors.white),
                      tooltip: 'Notes',
                    ),
                    if (!(exerciseType == ExerciseType.duration &&
                        widget.editorType == RoutineEditorMode.log))
                      IconButton(
                        onPressed: _addSet,
                        icon: const FaIcon(FontAwesomeIcons.solidSquarePlus,
                            size: 22, color: Colors.white),
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
                    padding: const EdgeInsets.all(16).copyWith(bottom: 100),
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            switch (exerciseType) {
                              ExerciseType.weights => WeightAndRepsSetHeader(
                                  editorType: widget.editorType,
                                  firstLabel: weightUnit().toUpperCase(),
                                  secondLabel: 'REPS',
                                ),
                              ExerciseType.bodyWeight => RepsSetHeader(
                                  editorType: widget.editorType,
                                ),
                              ExerciseType.duration => DurationSetHeader(
                                  editorType: widget.editorType,
                                )
                            },
                            if (currentSets.isEmpty &&
                                withReps(type: exerciseType))
                              Column(
                                children: [
                                  const SizedBox(height: 10),
                                  NoListEmptyState(
                                      message:
                                          "Tap the + button to start adding sets to your exercise"),
                                ],
                              ),
                            const SizedBox(height: 20),
                            switch (exerciseType) {
                              ExerciseType.weights => _WeightAndRepsSetListView(
                                  sets: currentSets
                                      .map((set) => set as WeightAndRepsSetDto)
                                      .toList(),
                                  updateSetCheck: _updateSetCheck,
                                  removeSet: _removeSet,
                                  updateReps: _updateReps,
                                  updateWeight: _updateWeight,
                                  controllers: _weightAndRepsControllers,
                                  onTapWeightEditor: _onTapWeightEditor,
                                  onTapRepsEditor: _onTapRepsEditor,
                                  editorType: widget.editorType,
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
                                ),
                            }
                          ],
                        ),
                        if (exerciseLog.notes.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: sapphireDark80,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              exerciseLog.notes,
                              textAlign: TextAlign.start,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                      fontWeight: FontWeight.w400,
                                      fontSize: 12,
                                      height: 1.8,
                                      color: Colors.white70),
                            ),
                          )
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
              bottom: 16,
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
        ],
      ),
    );
  }
}

class _WeightAndRepsSetListView extends StatelessWidget {
  final RoutineEditorMode editorType;
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
      required this.editorType});

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
      required this.editorType});

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
      required this.editorType});

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
