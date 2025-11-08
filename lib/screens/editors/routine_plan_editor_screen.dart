import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import 'package:tracker_app/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:tracker_app/utils/dialog_utils.dart';

import '../../dtos/appsync/routine_plan_dto.dart';
import '../../dtos/appsync/routine_template_dto.dart';
import '../../utils/general_utils.dart';
import '../../utils/routine_editors_utils.dart';
import '../../widgets/buttons/opacity_button_widget_two.dart';
import '../../widgets/empty_states/no_list_empty_state.dart';
import '../../widgets/routine/preview/routine_template_grid_item.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

class RoutinePlanEditorScreen extends StatefulWidget {
  static const routeName = '/routine-plan-editor';

  final RoutinePlanDto? plan;

  const RoutinePlanEditorScreen({super.key, this.plan});

  @override
  State<RoutinePlanEditorScreen> createState() =>
      _RoutinePlanEditorScreenState();
}

class _RoutinePlanEditorScreenState extends State<RoutinePlanEditorScreen> {
  late TextEditingController _planNameController;
  late TextEditingController _planNotesController;

  List<RoutineTemplateDto> _routineTemplates = [];

  void _selectTemplatesInLibrary() async {
    final plan = widget.plan;

    final exerciseAndRoutineController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);

    final routineTemplates = exerciseAndRoutineController.templates
        .where((template) => template.planId == plan?.id)
        .toList();

    showTemplatesInLibrary(
        context: context,
        templatesToExclude: [...routineTemplates, ..._routineTemplates],
        onSelected: (List<RoutineTemplateDto> templates) async {
          setState(() {
            _routineTemplates.addAll(templates);
          });
        });
  }

  bool _validateRoutinePlanInputs() {
    if (_planNameController.text.isEmpty) {
      _showSnackbar('Please provide a name for this plan');
      return false;
    }
    if (_routineTemplates.isEmpty) {
      _showSnackbar("Plan must have workout template(s)");
      return false;
    }
    return true;
  }

  void _showSnackbar(String message) {
    showSnackbar(context: context, message: message);
  }

  void _createRoutinePlan() async {
    if (!_validateRoutinePlanInputs()) return;

    final newPlan = RoutinePlanDto(
      name: _planNameController.text,
      notes: _planNotesController.text,
    );

    final templateController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);

    final createdPlan = await templateController.savePlan(planDto: newPlan);

    if (createdPlan != null) {
      for (final template in _routineTemplates) {
        final templateWithPlanId = template.copyWith(planId: createdPlan.id);
        await templateController.updateTemplate(template: templateWithPlanId);
      }
    }

    _navigateBack();
  }

  void _updateRoutinePlan() {
    if (!_validateRoutinePlanInputs()) return;
    final plan = widget.plan;
    if (plan != null) {
      showBottomSheetWithMultiActions(
          context: context,
          description: "Do you want to update plan?",
          leftAction: _closeDialog,
          rightAction: () {
            _closeDialog();
            final updatedTemplate = _getUpdatedRoutinePlan(plan: plan);
            _doUpdateRoutinePlan(planToBeUpdated: updatedTemplate);
            _navigateBack(plan: updatedTemplate);
          },
          leftActionLabel: 'Cancel',
          rightActionLabel: 'Update',
          isRightActionDestructive: true,
          title: "Update plan");
    }
  }

  RoutinePlanDto _getUpdatedRoutinePlan({required RoutinePlanDto plan}) {
    final planToBeUpdated = plan.copyWith(
        name: _planNameController.text.trim(),
        notes: _planNotesController.text.trim());

    return planToBeUpdated;
  }

  void _doUpdateRoutinePlan({required RoutinePlanDto planToBeUpdated}) async {
    final planProvider = Provider.of<SupabaseExerciseAndRoutineController>(
        context,
        listen: false);

    await planProvider.updatePlan(planDto: planToBeUpdated);

    for (final template in _routineTemplates) {
      final templateWithPlanId = template.copyWith(planId: planToBeUpdated.id);
      await planProvider.updateTemplate(template: templateWithPlanId);
    }
  }

  void _dismissKeyboard() {
    FocusScope.of(context).unfocus();
  }

  void _closeDialog() {
    Navigator.of(context).pop();
  }

  void _navigateBack({RoutinePlanDto? plan}) {
    context.pop(plan);
  }

  void _removeTemplate(
      {required RoutineTemplateDto templateToBeRemoved}) async {
    final plan = widget.plan;

    if (plan != null) {
      final templateProvider =
          Provider.of<SupabaseExerciseAndRoutineController>(context,
              listen: false);
      final templateWithoutIdPlanId = templateToBeRemoved.copyWith(planId: "");
      await templateProvider.updateTemplate(template: templateWithoutIdPlanId);

      setState(() {
        _routineTemplates
            .removeWhere((template) => template.id == templateToBeRemoved.id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    /// We listen for [_routineTemplates] have been updated i.e. Have their planId removed
    final exerciseAndRoutineController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);

    final children = _routineTemplates
        .mapIndexed(
          (index, template) => GestureDetector(
            onTap: () {
              _removeTemplate(templateToBeRemoved: template);
            },
            child: Badge(
                backgroundColor: Colors.transparent,
                label: FaIcon(FontAwesomeIcons.squareXmark),
                alignment: Alignment.topRight,
                smallSize: 12,
                isLabelVisible: true,
                offset: Offset(-6, 0),
                child: RoutineTemplateGridItemWidget(template: template)),
          ),
        )
        .toList();

    final plan = widget.plan;

    if (exerciseAndRoutineController.errorMessage.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSnackbar(exerciseAndRoutineController.errorMessage);
      });
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
          appBar: AppBar(
              backgroundColor: appBarBackgroundColor(context: context),
              surfaceTintColor: Colors.transparent,
              scrolledUnderElevation: 0,
              leading: IconButton(
                  icon: const FaIcon(FontAwesomeIcons.arrowLeftLong),
                  onPressed: context.pop),
              actions: [
                IconButton(
                    onPressed: _selectTemplatesInLibrary,
                    icon: const FaIcon(FontAwesomeIcons.solidSquarePlus)),
              ]),
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
                  spacing: 10,
                  children: [
                    Column(
                      spacing: 10,
                      children: [
                        TextField(
                          controller: _planNameController,
                          cursorColor: isDarkMode ? Colors.white : Colors.black,
                          decoration: InputDecoration(
                            hintText: "New plan",
                          ),
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.words,
                          style: TextStyle(
                              fontWeight: FontWeight.w400,
                              color: isDarkMode ? Colors.white : Colors.black,
                              fontSize: 14),
                        ),
                        TextField(
                          controller: _planNotesController,
                          cursorColor: isDarkMode ? Colors.white : Colors.black,
                          decoration: InputDecoration(
                            hintText: "Notes",
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
                    if (_routineTemplates.isNotEmpty)
                      Expanded(
                        child: GridView.count(
                            padding: const EdgeInsets.all(4),
                            shrinkWrap: true,
                            crossAxisCount: 2,
                            childAspectRatio: 1,
                            mainAxisSpacing: 10.0,
                            crossAxisSpacing: 10.0,
                            children: children),
                      ),
                    if (_routineTemplates.isNotEmpty)
                      SafeArea(
                        minimum: EdgeInsets.symmetric(horizontal: 4),
                        child: SizedBox(
                            width: double.infinity,
                            child: OpacityButtonWidgetTwo(
                                buttonColor:
                                    Theme.of(context).colors.vibrantAccent,
                                label: plan != null
                                    ? "Update Plan"
                                    : "Create Plan",
                                onPressed: plan != null
                                    ? _updateRoutinePlan
                                    : _createRoutinePlan)),
                      ),
                    if (_routineTemplates.isEmpty)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10.0),
                          child: const NoListEmptyState(
                              message:
                                  "Tap the + button to start adding workout templates to your plan"),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          )),
    );
  }

  @override
  void initState() {
    super.initState();

    final plan = widget.plan;

    _planNameController = TextEditingController(text: plan?.name);
    _planNotesController = TextEditingController(text: plan?.notes);

    final exerciseAndRoutineController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);

    _routineTemplates = exerciseAndRoutineController.templates
        .where((template) => template.planId == plan?.id)
        .toList();
  }

  @override
  void dispose() {
    _planNameController.dispose();
    _planNotesController.dispose();
    super.dispose();
  }
}
