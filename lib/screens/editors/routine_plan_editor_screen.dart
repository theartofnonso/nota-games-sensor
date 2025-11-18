import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import 'package:provider/provider.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/utils/dialog_utils.dart';

import '../../dtos/appsync/routine_plan_dto.dart';
import '../../utils/general_utils.dart';
import '../../widgets/buttons/opacity_button_widget_two.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

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

  bool _validateRoutinePlanInputs() {
    if (_planNameController.text.isEmpty) {
      _showSnackbar('Please provide a name for this plan');
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
      name: _planNameController.text.trim(),
      notes: _planNotesController.text.trim(),
    );

    final templateController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);

    final createdPlan = await templateController.savePlan(planDto: newPlan);

    _navigateBack(plan: createdPlan);
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

    await planProvider.updatePlan(plan: planToBeUpdated);
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

  @override
  Widget build(BuildContext context) {
    final exerciseAndRoutineController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);

    if (exerciseAndRoutineController.errorMessage.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showSnackbar(exerciseAndRoutineController.errorMessage);
      });
    }

    return Scaffold(
      appBar: AppBar(
          backgroundColor: appBarBackgroundColor(context: context),
          surfaceTintColor: Colors.transparent,
          scrolledUnderElevation: 0,
          leading: IconButton(
              icon: const FaIcon(FontAwesomeIcons.arrowLeftLong),
              onPressed: context.pop)),
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
                    controller: _planNameController,
                    cursorColor: Colors.white,
                    decoration: const InputDecoration(
                      hintText: "Plan name",
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.words,
                    style: const TextStyle(
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
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
                    controller: _planNotesController,
                    cursorColor: Colors.white,
                    decoration: const InputDecoration(
                      hintText: "Notes (optional)",
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                    ),
                    maxLines: null,
                    keyboardType: TextInputType.text,
                    textCapitalization: TextCapitalization.sentences,
                    style: const TextStyle(
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                        fontSize: 14),
                  ),
                ),
                const Spacer(),
                SafeArea(
                  minimum: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                      width: double.infinity,
                      child: OpacityButtonWidgetTwo(
                          buttonColor: Theme.of(context).colors.vibrantAccent,
                          label: widget.plan?.id.isNotEmpty ?? false
                              ? "Update Plan"
                              : "Create Plan",
                          onPressed: widget.plan?.id.isNotEmpty ?? false
                              ? _updateRoutinePlan
                              : _createRoutinePlan)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    final plan = widget.plan;

    _planNameController = TextEditingController(text: plan?.name);
    _planNotesController = TextEditingController(text: plan?.notes);
  }

  @override
  void dispose() {
    _planNameController.dispose();
    _planNotesController.dispose();
    super.dispose();
  }
}
