import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/controllers/exercise_log_controller.dart';
import 'package:trainware/dtos/appsync/exercise_dto.dart';
import 'package:trainware/dtos/exercise_log_dto.dart';
import 'package:trainware/enums/routine_editor_type_enums.dart';
import 'package:trainware/utils/app_privileges.dart';
import 'package:trainware/utils/dialog_utils.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/widgets/loading/coach_loading_overlay.dart';

import 'package:trainware/utils/theme/color_extensions.dart';
import '../../dtos/appsync/routine_template_dto.dart';
import '../../utils/general_utils.dart';
import '../../utils/name_notes_bottom_sheet.dart';
import '../../utils/routine_editors_utils.dart';
import '../../widgets/buttons/opacity_button_widget_two.dart';
import '../../widgets/routine/editors/exercise_log_list_item.dart';

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

  void _createRoutineTemplate() async {
    if (!_validateRoutineTemplateInputs()) return;

    // Check if plan is a system plan
    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);
    final plan = controller.planWhere(id: widget.planId);

    if (!AppPrivileges.isSelfCoaching && (plan?.isSystemPlan ?? false)) {
      _showSnackbar('Cannot add workouts to system plans.');
      return;
    }

    final exerciseLogController =
        Provider.of<ExerciseLogController>(context, listen: false);
    final exercises = exerciseLogController.exerciseLogs;

    final template = RoutineTemplateDto(
        id: "",
        name: _templateNameController.text.trim(),
        exerciseTemplates: exercises,
        planId: widget.planId);

    if (AppConfig.isCoach) showCoachLoadingOverlay(context);
    try {
      await Provider.of<SupabaseExerciseAndRoutineController>(context,
              listen: false)
          .saveTemplate(templateDto: template);
      if (mounted) _navigateBack();
    } finally {
      if (AppConfig.isCoach) hideCoachLoadingOverlay(context);
    }
  }

  void _updateRoutineTemplate() {
    if (!_validateRoutineTemplateInputs()) return;
    final template = widget.template;
    if (template != null) {
      showBottomSheetWithSingleAction(
          context: context,
          title: "Update workout",
          description: "Do you want to update workout?",
          action: () async {
            _closeDialog();
            if (AppConfig.isCoach) showCoachLoadingOverlay(context);
            try {
              final updatedTemplate =
                  _getUpdatedRoutineTemplate(template: template);
              final didUpdate = await _doUpdateRoutineTemplate(
                updatedTemplate: updatedTemplate,
              );
              if (didUpdate && mounted) {
                _navigateBack(template: updatedTemplate);
              }
            } finally {
              if (AppConfig.isCoach) hideCoachLoadingOverlay(context);
            }
          },
          actionLabel: 'Update',
          isDestructive: false);
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
      exerciseTemplates: exerciseLogs,
    );
  }

  Future<bool> _doUpdateRoutineTemplate(
      {required RoutineTemplateDto updatedTemplate}) async {
    final templateProvider = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);

    final updatedRoutineTemplate =
        _getUpdatedRoutineTemplate(template: updatedTemplate);

    await templateProvider.updateTemplate(template: updatedRoutineTemplate);
    return true;
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
    showNameNotesBottomSheet(
      context: context,
      title: isUpdate ? "Update workout" : "Create workout",
      primaryButtonLabel: isUpdate ? "Update Workout" : "Create Workout",
      initialName: _templateNameController.text.trim(),
      initialNotes: _templateNotesController.text.trim(),
      emptyNameMessage: 'Please provide a name for this workout',
      compact: true,
    ).then((result) async {
      if (result == null) return;
      _templateNameController.text = result.name;
      _templateNotesController.text = result.notes;

      if (isUpdate) {
        final template = widget.template;
        if (template != null && mounted) {
          final updatedTemplate =
              _getUpdatedRoutineTemplate(template: template);
          if (AppConfig.isCoach) showCoachLoadingOverlay(context);
          try {
            await _doUpdateRoutineTemplate(updatedTemplate: updatedTemplate);
            if (mounted) _navigateBack(template: updatedTemplate);
          } finally {
            if (AppConfig.isCoach) hideCoachLoadingOverlay(context);
          }
        }
      } else {
        _createRoutineTemplate();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        final shouldPop = await _handleBackNavigation();
        if (shouldPop && mounted && context.mounted) {
          context.pop();
        }
      },
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
                minimum: const EdgeInsets.all(20),
                child: Stack(
                  children: [
                    // Main scrollable content: header + list
                    Positioned.fill(
                      bottom: exerciseTemplates.isNotEmpty ? 88.0 : 0.0,
                      child: GestureDetector(
                        onTap: _dismissKeyboard,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header: template name + add button (top-right)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 8, 0, 4),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
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
                                  if (AppConfig.isCoach)
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
                            const SizedBox(height: 8),
                            Expanded(
                              child: exerciseTemplates.isEmpty
                                  ? Center(
                                      child: Text(
                                        'No exercises in this workout yet.\nTap + to add exercises.',
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
                                      itemCount: exerciseTemplates.length,
                                      onReorder: (oldIndex, newIndex) {
                                        if (newIndex > oldIndex) {
                                          newIndex -= 1;
                                        }

                                        final updated =
                                            exerciseTemplates.toList();
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
                                        final exerciseLog =
                                            exerciseTemplates[index];
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
                                                showOnlyTotalSets: true,
                                                showStatusIcon: true,
                                                onTap: () {
                                                  showExerciseLogEditor(
                                                    context: context,
                                                    exerciseLogId:
                                                        exerciseLog.exercise.id,
                                                    editorType:
                                                        RoutineEditorMode.edit,
                                                    showSetCheck: false,
                                                    templateId: widget.template?.id,
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
                    // Bottom fixed CTA (does not scroll) – only when there is at least one exercise
                    if (exerciseTemplates.isNotEmpty)
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
                              label: widget.template?.id.isNotEmpty ?? false
                                  ? "Update Workout"
                                  : "Create Workout",
                              onPressed: () {
                                final isUpdate =
                                    widget.template?.id.isNotEmpty ?? false;
                                if (isUpdate) {
                                  _updateRoutineTemplate();
                                } else {
                                  _showTemplateNameBottomSheet(isUpdate: false);
                                }
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
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    // Ensure we don't reuse any in-memory exercise logs or cached routine log
    // state from an active workout when editing templates.
    Provider.of<ExerciseLogController>(context, listen: false).clearLocal();

    _initializeWorkoutTemplateData();
    _initializeTextControllers();

    // For template editing, only clear local controller state on dispose;
    // do NOT clear or touch the cached pending routine log.
    _onDisposeCallback =
        Provider.of<ExerciseLogController>(context, listen: false).clearLocal;
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
    _templateNotesController =
        TextEditingController(text: template?.notes ?? "");
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

  Future<bool> _confirmRemoveExercise(ExerciseLogDto exerciseLog) async {
    return confirmRemoveExerciseBottomSheet(
      context: context,
      exerciseName: exerciseLog.exercise.name,
      fromLabel: 'template',
    );
  }

  /// Handles back navigation - always shows confirmation
  Future<bool> _handleBackNavigation() async {
    final shouldLeave = await confirmDiscardChangesBottomSheet(
      context: context,
      title: 'Leave editor?',
      description: 'Are you sure you want to leave?',
    );

    return shouldLeave;
  }

  @override
  void dispose() {
    _onDisposeCallback();
    _templateNameController.dispose();
    _templateNotesController.dispose();
    super.dispose();
  }
}
