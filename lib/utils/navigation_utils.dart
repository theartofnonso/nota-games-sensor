import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/screens/editors/exercise_editor_screen.dart';
import 'package:trainware/screens/exercise/history/exercise_home_screen.dart';
import 'package:trainware/screens/preferences/settings_screen.dart';
import 'package:trainware/utils/dialog_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

import '../dtos/appsync/exercise_dto.dart';
import '../dtos/appsync/routine_log_dto.dart';
import '../dtos/appsync/routine_plan_dto.dart';
import '../dtos/appsync/routine_template_dto.dart';
import '../dtos/viewmodels/exercise_editor_arguments.dart';
import '../dtos/viewmodels/past_routine_log_arguments.dart';
import '../dtos/viewmodels/routine_log_arguments.dart';
import '../dtos/viewmodels/routine_plan_arguments.dart';
import '../dtos/viewmodels/routine_template_arguments.dart';
import '../screens/editors/past_routine_log_editor_screen.dart';
import '../screens/editors/routine_log_editor_screen.dart';
import '../screens/editors/routine_template_editor_screen.dart';
import '../screens/logs/routine_log_screen.dart';
import '../screens/routines/routine_plan.dart';
import '../screens/routines/routine_plans_screen.dart';
import '../screens/routines/routine_template_screen.dart';
import '../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../widgets/buttons/opacity_button_widget_two.dart';

Future<ExerciseDto?> navigateToExerciseEditor(
    {required BuildContext context, ExerciseEditorArguments? arguments}) async {
  final exercise = await context.push(ExerciseEditorScreen.routeName,
      extra: arguments) as ExerciseDto?;
  return exercise;
}

Future<RoutineTemplateDto?> navigateToRoutineTemplateEditor(
    {required BuildContext context,
    required RoutineTemplateArguments arguments}) async {
  final template = await showAppBottomSheet<RoutineTemplateDto>(
    context: context,
    isDraggable: true,
    initialChildSize: 0.9,
    minChildSize: 0.6,
    maxChildSize: 0.98,
    child: RoutineTemplateEditorScreen(
      template: arguments.template,
      planId: arguments.planId,
    ),
  );
  return template;
}

Future<RoutinePlanDto?> navigateToRoutinePlanEditor(
    {required BuildContext context, RoutinePlanArguments? arguments}) async {
  final initialPlan = arguments?.plan;
  final isEditing = initialPlan != null && initialPlan.id.isNotEmpty;

  final nameController = TextEditingController(text: initialPlan?.name ?? '');
  final notesController = TextEditingController(text: initialPlan?.notes ?? '');

  RoutinePlanDto? result;

  await showAppBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    child: Builder(
      builder: (context) {
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Padding(
          padding: EdgeInsets.only(
            top: 26,
            bottom: 26 + bottomInset,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: Text(
                  isEditing ? 'Edit Plan' : 'Create Plan',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 16),
              // Plan name
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: TextField(
                  controller: nameController,
                  cursorColor: isDark ? Colors.white : Colors.black,
                  decoration: const InputDecoration(
                    hintText: "Plan name",
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
              ),
              // Full-bleed divider between name and notes
              Builder(
                builder: (context) {
                  final isDarkInner =
                      Theme.of(context).brightness == Brightness.dark;
                  final color = isDarkInner
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.06);
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Divider(
                      thickness: 0.5,
                      color: color,
                      height: 16,
                    ),
                  );
                },
              ),
              // Optional notes
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: TextField(
                  controller: notesController,
                  cursorColor: isDark ? Colors.white : Colors.black,
                  decoration: const InputDecoration(
                    hintText: "Notes (optional)",
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                  maxLines: null,
                  minLines: 3,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 26),
                child: SizedBox(
                  width: double.infinity,
                  child: OpacityButtonWidgetTwo(
                    buttonColor: Theme.of(context).colors.vibrantAccent,
                    label: isEditing ? "Update Plan" : "Create Plan",
                    onPressed: () async {
                      final name = nameController.text.trim();
                      final notes = notesController.text.trim();

                      if (name.isEmpty) {
                        showSnackbar(
                          context: context,
                          message: 'Please provide a name for this plan',
                        );
                        return;
                      }

                      final controller =
                          context.read<SupabaseExerciseAndRoutineController>();

                      if (isEditing) {
                        final updated = initialPlan.copyWith(
                          name: name,
                          notes: notes,
                        );
                        await controller.updatePlan(plan: updated);
                        result = updated;
                      } else {
                        final newPlan =
                            RoutinePlanDto(name: name, notes: notes);
                        final created =
                            await controller.savePlan(planDto: newPlan);
                        result = created;
                      }

                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );

  return result;
}

void navigateToPastRoutineLogEditor(
    {required BuildContext context,
    required PastRoutineLogArguments arguments}) async {
  final log = await showAppBottomSheet<RoutineLogDto>(
    context: context,
    isDraggable: true,
    initialChildSize: 0.9,
    minChildSize: 0.6,
    maxChildSize: 0.98,
    child: PastRoutineLogEditorScreen(log: arguments.log),
  );
  if (log != null && context.mounted) {
      navigateWithSlideTransition(
        context: context,
      child: RoutineLogScreen(id: log.id, isEditable: true),
      );
  }
}

Future<void> navigateToRoutineLogEditor(
    {required BuildContext context,
    required RoutineLogArguments arguments}) async {
  final log = await showAppBottomSheet<RoutineLogDto>(
    context: context,
    isDraggable: true,
    initialChildSize: 0.9,
    minChildSize: 0.6,
    maxChildSize: 0.98,
    child: RoutineLogEditorScreen(
      log: arguments.log,
      mode: arguments.editorMode,
      cached: arguments.cached,
    ),
  );
  if (log != null) {
    if (context.mounted) {
      navigateWithSlideTransition(
        context: context,
        child: RoutineLogScreen(id: log.id, isEditable: true),
      );
    }
  }
}

Future<RoutineLogDto?> navigateToRoutineEditorAndReturnLog(
    {required BuildContext context,
    required RoutineLogArguments arguments}) async {
  final log = await showAppBottomSheet<RoutineLogDto>(
    context: context,
    isDraggable: true,
    initialChildSize: 0.9,
    minChildSize: 0.6,
    maxChildSize: 0.98,
    child: RoutineLogEditorScreen(
      log: arguments.log,
      mode: arguments.editorMode,
      cached: arguments.cached,
    ),
  );
  return log;
}

void navigateToRoutineTemplatePreview(
    {required BuildContext context, required RoutineTemplateDto template}) {
  context.push(RoutineTemplateScreen.routeName, extra: template);
}

void navigateToRoutinePlanPreview(
    {required BuildContext context, required RoutinePlanDto plan}) {
  context.push(RoutinePlanScreen.routeName, extra: plan);
}

Future<void> navigateToRoutineLogPreview(
    {required BuildContext context,
    required RoutineLogDto log,
    bool isEditable = true}) {
  return navigateWithSlideTransition(
    context: context,
    child: RoutineLogScreen(id: log.id, isEditable: isEditable),
  );
}

Future<void> navigateToExerciseHome(
    {required BuildContext context, required ExerciseDto exercise}) async {
  await context.push(ExerciseHomeScreen.routeName, extra: exercise);
}

void navigateToRoutineHome({required BuildContext context}) {
  context.push(RoutinePlansScreen.routeName);
}

Future<void> navigateToSettings({required BuildContext context}) async {
  await context.push(SettingsScreen.routeName);
}

/// Create a screen on demand
Future navigateWithSlideTransition(
    {required BuildContext context, required Widget child}) {
  final route = PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 1.0);
      const end = Offset.zero;
      const curve = Curves.ease;
      final tween =
          Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      final offsetAnimation = animation.drive(tween);
      return SlideTransition(
        position: offsetAnimation,
        child: child,
      );
    },
  );

  return Navigator.of(context).push(route);
}
