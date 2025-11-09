import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import 'package:tracker_app/enums/muscle_group_enums.dart';
import 'package:tracker_app/utils/dialog_utils.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

import '../../controllers/supabase_exercise_and_routine_controller.dart';
import '../../dtos/appsync/exercise_dto.dart';
import '../../enums/exercise_type_enums.dart';
import '../../logger.dart';
import '../../utils/general_utils.dart';
import '../../widgets/buttons/opacity_button_widget_two.dart';
import '../../widgets/dividers/label_divider.dart';
import '../../widgets/list_tile.dart';
import '../../widgets/picker.dart';
import '../exercise/exercise_type_screen.dart';

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
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
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

    return PopScope(
        canPop: false,
        child: Scaffold(
          appBar: AppBar(
            backgroundColor: appBarBackgroundColor(context: context),
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            leading: IconButton(
              icon: const FaIcon(
                FontAwesomeIcons.squareXmark,
              ),
              onPressed: context.pop,
            ),
            title: Text(exercise?.name ?? "Create New Exercise".toUpperCase()),
            centerTitle: true,
            actions: [
              exercise != null
                  ? IconButton(
                      icon: const FaIcon(FontAwesomeIcons.solidSquareCheck),
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
                  spacing: 20,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _exerciseNameController,
                      decoration: InputDecoration(
                        hintText: "Exercise Name",
                      ),
                      cursorColor: isDarkMode ? Colors.white : Colors.black,
                      keyboardType: TextInputType.text,
                      textCapitalization: TextCapitalization.words,
                      style: TextStyle(
                          fontWeight: FontWeight.w400,
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontSize: 14),
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
                            trailing: FaIcon(
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
                            label:
                                "Choose how to log this exercise".toUpperCase(),
                            labelColor: Theme.of(context).colorScheme.onSurface,
                            dividerColor: Theme.of(context).colors.dividerColor,
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
                              onTap: _navigateToExerciseTypeScreen,
                              leading: Text(_exerciseType.name,
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
                              trailing: FaIcon(
                                FontAwesomeIcons.arrowRightLong,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    const Spacer(),
                    if (exercise == null)
                      SafeArea(
                        minimum: EdgeInsets.all(10),
                        child: SizedBox(
                          width: double.infinity,
                          child: OpacityButtonWidgetTwo(
                              onPressed: _createExercise,
                              label: "Create Exercise",
                              buttonColor:
                                  Theme.of(context).colors.vibrantAccent),
                        ),
                      ),
                  ]),
            ),
          ),
        ));
  }

  void _showSnackbar(String message) {
    showSnackbar(context: context, message: message);
  }

  void _selectPrimaryMuscleGroup() {
    FocusScope.of(context).unfocus();
    displayBottomSheet(
        height: 240,
        context: context,
        child: GenericPicker(
          items: MuscleGroup.sortedValues,
          labelBuilder: (muscle) => muscle.name,
          onItemSelected: (value) {
            Navigator.of(context).pop();
            setState(() {
              _primaryMuscleGroup = value;
            });
          },
        ));
  }

  void _navigateToExerciseTypeScreen() async {
    if (widget.exercise != null) {
      showSnackbar(
          context: context,
          message: "Exercise type cannot be changed after creation.");
      return;
    }

    /// We don't want to allow editing of exercise type once created.
    final type = await Navigator.of(context).push(MaterialPageRoute(
        builder: (context) =>
            ExerciseTypeScreen(exerciseType: _exerciseType))) as ExerciseType?;
    if (type != null) {
      setState(() {
        _exerciseType = type;
      });
    }
  }

  void _createExercise() async {
    final exerciseName = _exerciseNameController.text.trim();

    if (exerciseName.isEmpty) {
      _showSnackbar("Please provide a name for this exercise");
      return;
    }

      final exercise = ExerciseDto(
          name: exerciseName,
          primaryMuscleGroup: _primaryMuscleGroup,
        type: _exerciseType);

    await Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false)
          .saveExercise(exerciseDto: exercise);

      logger.i("created exercise ${exercise.toString()}");
      if (mounted) {
        context.pop();
    }
  }

  void _updateExercise() async {
    final exerciseName = _exerciseNameController.text.trim();

    if (exerciseName.isEmpty) return;

    if (exerciseName.isEmpty) {
      _showSnackbar("Please provide a name for this exercise");
    } else {
      final exercise = widget.exercise;
      if (exercise == null) return;

      final exerciseToBeUpdated = exercise.copyWith(
          name: exerciseName.trim(), primaryMuscleGroup: _primaryMuscleGroup);
      await Provider.of<SupabaseExerciseAndRoutineController>(context,
              listen: false)
          .updateExercise(exercise: exerciseToBeUpdated);

      if (mounted) {
        context.pop(exerciseToBeUpdated);
      }
    }
  }

  @override
  void initState() {
    super.initState();

    final previousExercise = widget.exercise;

    _exerciseNameController =
        TextEditingController(text: previousExercise?.name);

    _primaryMuscleGroup = previousExercise != null
        ? previousExercise.primaryMuscleGroup
        : MuscleGroup.values.first;

    _exerciseType =
        previousExercise != null ? previousExercise.type : ExerciseType.weights;
  }
}
