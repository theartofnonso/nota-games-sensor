import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import 'package:trainware/enums/muscle_group_enums.dart';
import 'package:trainware/utils/dialog_utils.dart';
import 'package:trainware/utils/exercise_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

import '../../controllers/supabase_exercise_and_routine_controller.dart';
import '../../dtos/appsync/exercise_dto.dart';
import '../../enums/exercise_type_enums.dart';
import '../../logger.dart';
import '../../utils/general_utils.dart';
import '../../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../../widgets/buttons/opacity_button_widget_two.dart';
import '../../widgets/dividers/label_divider.dart';
import '../../widgets/list_tile.dart';
import '../../widgets/picker.dart';
import '../../widgets/muscle_group/muscle_group_grid_picker.dart';

class ExerciseEditorScreen extends StatefulWidget {
  static const routeName = '/exercise-editor';

  final ExerciseDto? exercise;

  const ExerciseEditorScreen({super.key, this.exercise});

  @override
  State<ExerciseEditorScreen> createState() => _ExerciseEditorScreenState();
}

class _ExerciseEditorScreenState extends State<ExerciseEditorScreen> {
  late MuscleGroup _primaryMuscleGroup;
  late ExerciseType _exerciseType;

  final logger = getLogger(className: "_ExerciseEditorScreenState");

  late TextEditingController _exerciseNameController;

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    final exerciseEditorController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: true);

    if (exerciseEditorController.errorMessage.isNotEmpty) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _showSnackbar(exerciseEditorController.errorMessage);
      });
    }

    final exercise = widget.exercise;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBackgroundColor(context: context),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const FaIcon(
            FontAwesomeIcons.solidCircleXmark,
          ),
          onPressed: context.pop,
        ),
        title: Text(exercise?.name ?? "Create New Exercise".toUpperCase()),
        centerTitle: true,
        actions: [
          exercise != null
              ? IconButton(
                  icon: const FaIcon(FontAwesomeIcons.solidCircleCheck),
                  onPressed: _updateExercise,
                )
              : const SizedBox.shrink(),
          const SizedBox(width: 12)
        ],
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: themeGradient(context: context),
        ),
        child: SafeArea(
          minimum: const EdgeInsets.all(10),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    spacing: 20,
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                          controller: _exerciseNameController,
                          decoration: const InputDecoration(
                            hintText: "Exercise Name",
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          cursorColor: isDarkMode ? Colors.white : Colors.black,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.words,
                          style: TextStyle(
                              fontWeight: FontWeight.w400,
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontSize: 14),
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        spacing: 8,
                        children: [
                          LabelDivider(
                            label: "Select muscle group to train".toUpperCase(),
                            labelColor: Theme.of(context).colorScheme.onSurface,
                            dividerColor: Theme.of(context).colors.dividerColor,
                            fontSize: 14,
                          ),
                          Text(
                              "Choose from a list of muscle groups to train for this custom exercise.",
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                      fontWeight: FontWeight.w400,
                                      color: isDarkMode
                                          ? Colors.white70
                                          : Colors.black)),
                          ThemeListTile(
                            child: ListTile(
                              onTap: _selectPrimaryMuscleGroup,
                              leading: Text(_primaryMuscleGroup.name,
                                  textAlign: TextAlign.start,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black)),
                              trailing: const FaIcon(
                                FontAwesomeIcons.arrowRightLong,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (exercise == null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 8,
                          children: [
                            LabelDivider(
                              label: "Choose how to log this exercise"
                                  .toUpperCase(),
                              labelColor:
                                  Theme.of(context).colorScheme.onSurface,
                              dividerColor:
                                  Theme.of(context).colors.dividerColor,
                              fontSize: 14,
                            ),
                            Text(
                                "You can log this exercise using reps only, reps and weights or duration.",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                        fontWeight: FontWeight.w400,
                                        color: isDarkMode
                                            ? Colors.white70
                                            : Colors.black)),
                            ThemeListTile(
                              child: ListTile(
                                onTap: _selectExerciseType,
                                leading: Text(_exerciseType.description,
                                    textAlign: TextAlign.start,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                            color: isDarkMode
                                                ? Colors.white
                                                : Colors.black)),
                                trailing: const FaIcon(
                                  FontAwesomeIcons.arrowRightLong,
                                  size: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              if (exercise == null)
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.all(10),
                  child: SizedBox(
                    width: double.infinity,
                    child: OpacityButtonWidgetTwo(
                        onPressed: _createExercise,
                        label: "Create Exercise",
                        buttonColor: Theme.of(context).colors.vibrantAccent),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSnackbar(String message) {
    showSnackbar(context: context, message: message);
  }

  void _selectPrimaryMuscleGroup() {
    FocusScope.of(context).unfocus();
    showAppBottomSheet(
      context: context,
      isDraggable: true,
      child: MuscleGroupGridPicker(
        selectedMuscleGroup: _primaryMuscleGroup,
        onSelect: (muscleGroup) {
          Navigator.of(context).pop();
          setState(() {
            _primaryMuscleGroup = muscleGroup;
          });
        },
      ),
    );
  }

  void _selectExerciseType() {
    if (widget.exercise != null) {
      showSnackbar(
          context: context,
          message: "Exercise type cannot be changed after creation.");
      return;
    }

    FocusScope.of(context).unfocus();
    showAppBottomSheet(
        context: context,
        isScrollControlled: false,
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: SizedBox(
            height: 240,
            child: GenericPicker(
              items: ExerciseType.values,
              labelBuilder: (type) => type.description,
              onItemSelected: (value) {
                Navigator.of(context).pop();
                setState(() {
                  _exerciseType = value;
                });
              },
            ),
          ),
        ));
  }

  void _createExercise() async {
    final exerciseName = _exerciseNameController.text.trim();

    if (exerciseName.isEmpty) {
      _showSnackbar("Please provide a name for this exercise");
      return;
    }

    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);

    // Check for similar exercises
    final similarExercises = findSimilarExercises(
      exerciseName: exerciseName,
      allExercises: controller.exercises.toList(),
    );

    // If similar exercises found, show dialog
    if (similarExercises.isNotEmpty) {
      final shouldProceed = await showSimilarExercisesDialog(
        context: context,
        exerciseName: exerciseName,
        similarExercises: similarExercises,
      );

      if (!shouldProceed) {
        return;
      }
    }

    final exercise = ExerciseDto(
        name: exerciseName,
        primaryMuscleGroup: _primaryMuscleGroup,
        type: _exerciseType);

    await controller.saveExercise(exerciseDto: exercise);

    logger.i("created exercise ${exercise.toString()}");
    if (mounted) {
      context.pop();
    }
  }

  void _updateExercise() async {
    final exerciseName = _exerciseNameController.text.trim();

    if (exerciseName.isEmpty) {
      _showSnackbar("Please provide a name for this exercise");
      return;
    }

    final exercise = widget.exercise;
    if (exercise == null) return;

    final controller = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);

    // Check for similar exercises (excluding the current exercise being updated)
    final similarExercises = findSimilarExercises(
      exerciseName: exerciseName,
      allExercises: controller.exercises.toList(),
      excludeExercise: exercise,
    );

    // If similar exercises found, show dialog
    if (similarExercises.isNotEmpty) {
      final shouldProceed = await showSimilarExercisesDialog(
        context: context,
        exerciseName: exerciseName,
        similarExercises: similarExercises,
      );

      if (!shouldProceed) {
        return;
      }
    }

    final exerciseToBeUpdated = exercise.copyWith(
        name: exerciseName.trim(), primaryMuscleGroup: _primaryMuscleGroup);
    await controller.updateExercise(exercise: exerciseToBeUpdated);

    if (mounted) {
      context.pop(exerciseToBeUpdated);
    }
  }

  @override
  void initState() {
    super.initState();

    final previousExercise = widget.exercise;

    _exerciseNameController =
        TextEditingController(text: previousExercise?.name);

    // Default to the first item in the muscle group list used by the picker
    // when creating a new exercise, otherwise preserve the existing value.
    _primaryMuscleGroup = previousExercise != null
        ? previousExercise.primaryMuscleGroup
        : MuscleGroup.sortedValues.first;

    _exerciseType =
        previousExercise != null ? previousExercise.type : ExerciseType.weights;
  }
}
