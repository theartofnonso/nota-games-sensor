import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/controllers/exercise_log_controller.dart';
import 'package:trainware/dtos/appsync/exercise_dto.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';
import 'package:trainware/enums/routine_editor_type_enums.dart';
import 'package:trainware/utils/dialog_utils.dart';
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';

import 'package:trainware/utils/theme/color_extensions.dart';
import '../../dtos/appsync/routine_template_dto.dart';
import '../../dtos/set_dtos/set_dto.dart';
import '../../dtos/set_dtos/weight_and_reps_dto.dart';
import '../../utils/general_utils.dart';
import '../../utils/routine_editors_utils.dart';
import '../../utils/routine_utils.dart';
import '../../widgets/buttons/opacity_button_widget_two.dart';
import '../../widgets/routine/editors/exercise_log_list_item.dart';
import '_add_exercise_list_item.dart';
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
        name: _templateNameController.text.trim(),
        exerciseTemplates: exercises,
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

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  void _closeDialog() {
    Navigator.of(context).pop();
  }

  void _navigateBack({RoutineTemplateDto? template}) {
    context.pop(template);
  }

  void _showTemplateNameBottomSheet({required bool isUpdate}) {
    final existingName = _templateNameController.text.trim();
    final controller = TextEditingController(text: existingName);

    showAppBottomSheet(
      context: context,
      isScrollControlled: true,
      child: Builder(
        builder: (context) {
          final bottomInset = MediaQuery.of(context).viewInsets.bottom;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return Padding(
            padding: EdgeInsets.only(
              left: 26,
              right: 26,
              top: 26,
              bottom: 26 + bottomInset,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUpdate ? "Update workout" : "Create workout",
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: controller,
                  cursorColor: isDark ? Colors.white : Colors.black,
                  decoration: const InputDecoration(
                    hintText: "Workout name",
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: OpacityButtonWidgetTwo(
                    buttonColor: Theme.of(context).colors.vibrantAccent,
                    label: isUpdate ? "Update Workout" : "Create Workout",
                    onPressed: () {
                      final name = controller.text.trim();
                      if (name.isEmpty) {
                        showSnackbar(
                            context: context,
                            message: 'Please provide a name for this workout');
                        return;
                      }

                      // Persist into the screen controller, then delegate to existing logic
                      _templateNameController.text = name;

                      Navigator.of(context).pop();

                      if (isUpdate) {
                        _updateRoutineTemplate();
                      } else {
                        _createRoutineTemplate();
                      }
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
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

    final exerciseTemplates = context
        .select((ExerciseLogController provider) => provider.exerciseLogs);

    bool isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom != 0;

    return Scaffold(
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
          final topPadding = MediaQuery.of(context).padding.top + 8;

          return Container(
            decoration: BoxDecoration(
              gradient: themeGradient(context: context),
            ),
            child: SafeArea(
              bottom: false,
              minimum: const EdgeInsets.only(bottom: 10.0),
              child: Stack(
                children: [
                  // Main scrollable content: header + list + spacer
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: _dismissKeyboard,
                      child: Column(
                        children: [
                          // Header: template name (read-only here)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                _templateNameController.text.isNotEmpty
                                    ? _templateNameController.text
                                    : 'New workout',
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
                            child: ListView.separated(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 8),
                              itemCount: exerciseTemplates.length + 1,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                if (index == exerciseTemplates.length) {
                                  return AddExerciseListItem(
                                    onTap: _selectExercisesInLibrary,
                                  );
                                }

                                final exerciseLog = exerciseTemplates[index];
                                final superSet = whereOtherExerciseInSuperSet(
                                    firstExercise: exerciseLog,
                                    exercises: exerciseTemplates);

                                return ExerciseLogListItem(
                                  exerciseLogDto: exerciseLog,
                                  superSet: superSet,
                                  onTap: () {
                                    showExerciseLogEditor(
                                      context: context,
                                      exerciseLogId: exerciseLog.exercise.id,
                                      editorType: RoutineEditorMode.edit,
                                    );
                                  },
                                  onMenuTap: () {
                                    _showExerciseActionsBottomSheet(
                                      exerciseLog: exerciseLog,
                                      onRemoveLog: () {
                                        exerciseLogController.removeExerciseLog(
                                            logId: exerciseLog.id);
                                      },
                                      onReplaceLog: () {
                                        _showReplaceExercisePicker(
                                            oldExerciseLog: exerciseLog);
                                      },
                                      onSuperSet: () {
                                        _showSuperSetExercisePicker(
                                            firstExerciseLog: exerciseLog);
                                      },
                                      onRemoveSuperSet: (String superSetId) {
                                        exerciseLogController.removeSuperSet(
                                            superSetId: exerciseLog.superSetId);
                                      },
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 90),
                        ],
                      ),
                    ),
                  ),
                  // Top overlay controls (back), matching Overview style
                  Positioned(
                    top: topPadding,
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
                          onPressed: _checkForUnsavedChanges,
                          color: Colors.white,
                          padding: const EdgeInsets.all(12),
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ),
                  ),
                  // Bottom fixed CTA (does not scroll) – vertically aligned similar to Overview FAB
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: SafeArea(
                      minimum: const EdgeInsets.only(
                          left: 20, right: 20, bottom: 16),
                      child: SizedBox(
                        width: double.infinity,
                        child: OpacityButtonWidgetTwo(
                          buttonColor: Theme.of(context).colors.vibrantAccent,
                          label: widget.template?.id.isNotEmpty ?? false
                              ? "Update Workout"
                              : "Create Workout",
                          onPressed: () {
                            final isUpdate =
                                widget.template?.id.isNotEmpty ?? false;
                            _showTemplateNameBottomSheet(isUpdate: isUpdate);
                          },
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
  void dispose() {
    _onDisposeCallback();
    _templateNameController.dispose();
    super.dispose();
  }
}
