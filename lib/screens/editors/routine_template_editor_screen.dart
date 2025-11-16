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
import '../../dtos/appsync/routine_template_dto.dart';
import '../../dtos/set_dtos/set_dto.dart';
import '../../dtos/set_dtos/weight_and_reps_dto.dart';
import '../../utils/general_utils.dart';
import '../../utils/routine_editors_utils.dart';
import '../../utils/routine_utils.dart';
import '../../widgets/buttons/opacity_button_widget_two.dart';
import '../../widgets/routine/editors/exercise_log_grid_item.dart';
import '../../widgets/weight_plate_calculator.dart';

class RoutineTemplateEditorScreen extends StatefulWidget {
  static const routeName = '/routine-template-editor';

  final RoutineTemplateDto? template;
  final String planId;

  const RoutineTemplateEditorScreen(
      {super.key, this.template, required this.planId});

  @override
  State<RoutineTemplateEditorScreen> createState() =>
      _RoutineTemplateEditorScreenState();
}

class _RoutineTemplateEditorScreenState
    extends State<RoutineTemplateEditorScreen> {
  late TextEditingController _templateNameController;
  late TextEditingController _templateNotesController;

  late Function _onDisposeCallback;

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

  void _createRoutineTemplate() async {
    if (!_validateRoutineTemplateInputs()) return;

    final exerciseLogController =
        Provider.of<ExerciseLogController>(context, listen: false);
    final exercises = exerciseLogController.exerciseLogs;

    final template = RoutineTemplateDto(
        id: "",
        name: _templateNameController.text,
        exerciseTemplates: exercises,
        notes: _templateNotesController.text,
        planId: widget.planId);

    await Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false)
        .saveTemplate(templateDto: template);
    _navigateBack();
  }

  void _updateRoutineTemplate() {
    if (!_validateRoutineTemplateInputs()) return;
    final template = widget.template;
    if (template != null) {
      showBottomSheetWithMultiActions(
          context: context,
          description: "Do you want to update workout?",
          leftAction: _closeDialog,
          rightAction: () {
            _closeDialog();
            final updatedTemplate =
                _getUpdatedRoutineTemplate(template: template);
            _doUpdateRoutineTemplate(updatedTemplate: updatedTemplate);
            _navigateBack(template: updatedTemplate);
          },
          leftActionLabel: 'Cancel',
          rightActionLabel: 'Update',
          isRightActionDestructive: true,
          title: "Update workout");
    }
  }

  RoutineTemplateDto _getUpdatedRoutineTemplate(
      {required RoutineTemplateDto template,
      List<ExerciseLogDto>? updatedExerciseLogs}) {
    final exerciseProvider =
        Provider.of<ExerciseLogController>(context, listen: false);
    final exerciseLogs = updatedExerciseLogs ?? exerciseProvider.exerciseLogs;

    return template.copyWith(
        name: _templateNameController.text.trim(),
        notes: _templateNotesController.text.trim(),
        exerciseTemplates: exerciseLogs);
  }

  void _doUpdateRoutineTemplate(
      {required RoutineTemplateDto updatedTemplate}) async {
    final templateProvider = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);

    final updatedRoutineTemplate =
        _getUpdatedRoutineTemplate(template: updatedTemplate);

    await templateProvider.updateTemplate(template: updatedRoutineTemplate);
  }

  void _checkForUnsavedChanges() {
    final exerciseProvider =
        Provider.of<ExerciseLogController>(context, listen: false);
    final exerciseLog1 = widget.template?.exerciseTemplates ?? [];
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
            _navigateBack();
          },
          rightActionLabel: 'Discard',
          isRightActionDestructive: true,
          title: "Discard changes");
    } else {
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
    Navigator.of(context).pop();
  }

  void _navigateBack({RoutineTemplateDto? template}) {
    context.pop(template);
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

    final exerciseTemplates = context
        .select((ExerciseLogController provider) => provider.exerciseLogs);

    bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom != 0;

    final children = exerciseTemplates.map((exerciseLog) {
      return ExerciseLogGridItemWidget(
        editorType: RoutineEditorMode.edit,
        exerciseLogDto: exerciseLog,
        superSet: whereOtherExerciseInSuperSet(
            firstExercise: exerciseLog, exercises: exerciseTemplates),
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

    return Scaffold(
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
              icon: const FaIcon(FontAwesomeIcons.circlePlus)),
          if (exerciseTemplates.length > 1)
            IconButton(
                onPressed: () =>
                    _reOrderExerciseLogs(exerciseLogs: exerciseTemplates),
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
          minimum: const EdgeInsets.only(right: 10.0, bottom: 10.0, left: 10.0),
          child: GestureDetector(
            onTap: _dismissKeyboard,
            child: Column(
              spacing: 20,
              children: [
                Column(
                  spacing: 10,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: Theme.of(context)
                              .extension<TRKRColors>()!
                              .borderLight,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.only(
                          left: 20, top: 6, bottom: 6, right: 6),
                      child: TextField(
                        controller: _templateNameController,
                        cursorColor: isDarkMode ? Colors.white : Colors.black,
                        decoration: InputDecoration(
                          hintText: "New workout",
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.words,
                        style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontSize: 14),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(
                          color: Theme.of(context)
                              .extension<TRKRColors>()!
                              .borderLight,
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.only(
                          left: 20, top: 6, bottom: 6, right: 6),
                      child: TextField(
                        controller: _templateNotesController,
                        cursorColor: isDarkMode ? Colors.white : Colors.black,
                        decoration: InputDecoration(
                          hintText: "Notes (optional)",
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        maxLines: null,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.sentences,
                        style: TextStyle(
                            fontWeight: FontWeight.w400,
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontSize: 14),
                      ),
                    ),
                  ],
                ),
                if (exerciseTemplates.isNotEmpty)
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
                const SizedBox(height: 10),
                SafeArea(
                  minimum: EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                      width: double.infinity,
                      child: OpacityButtonWidgetTwo(
                          buttonColor: Theme.of(context).colors.vibrantAccent,
                          label: widget.template?.id.isNotEmpty ?? false
                              ? "Update Workout"
                              : "Create Workout",
                          onPressed: widget.template?.id.isNotEmpty ?? false
                              ? _updateRoutineTemplate
                              : _createRoutineTemplate)),
                ),
              ],
            ),
          ),
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

    _initializeWorkoutTemplateData();
    _initializeTextControllers();

    _onDisposeCallback =
        Provider.of<ExerciseLogController>(context, listen: false).onClear;
  }

  void _initializeWorkoutTemplateData() {
    final exercises = widget.template?.exerciseTemplates;
    if (exercises != null && exercises.isNotEmpty) {
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
    final template = widget.template;
    _templateNameController = TextEditingController(text: template?.name);
    _templateNotesController = TextEditingController(text: template?.notes);
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
    _onDisposeCallback();
    _templateNameController.dispose();
    _templateNotesController.dispose();
    super.dispose();
  }
}
