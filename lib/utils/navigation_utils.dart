import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/screens/editors/exercise_editor_screen.dart';
import 'package:trainware/screens/editors/routine_log_editor_screen.dart';
import 'package:trainware/screens/exercise/history/exercise_home_screen.dart';
import 'package:trainware/screens/preferences/settings_screen.dart';
import 'package:trainware/screens/home.dart';

import '../dtos/appsync/exercise_dto.dart';
import '../dtos/appsync/routine_log_dto.dart';
import '../dtos/appsync/routine_plan_dto.dart';
import '../dtos/appsync/routine_template_dto.dart';
import '../dtos/viewmodels/exercise_editor_arguments.dart';
import '../dtos/viewmodels/past_routine_log_arguments.dart';
import '../dtos/viewmodels/routine_log_arguments.dart';
import '../dtos/viewmodels/routine_plan_arguments.dart';
import '../dtos/viewmodels/routine_template_arguments.dart';
import '../enums/routine_editor_type_enums.dart';
import '../screens/editors/past_routine_log_editor_screen.dart';
import '../screens/editors/routine_template_editor_screen.dart';
import '../screens/logs/routine_log_screen.dart';
import '../screens/routines/routine_plan.dart';
import '../screens/routines/routine_plans_screen.dart';
import '../screens/routines/routine_template_screen.dart';
import '../utils/name_notes_bottom_sheet.dart';
import '../widgets/bottom_sheets/app_bottom_sheet.dart';
import 'editor_bottom_sheet.dart';

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

  // Reuse the shared name+notes bottom sheet so plan and template editing
  // have a consistent UX.
  final details = await showNameNotesBottomSheet(
    context: context,
    title: isEditing ? 'Edit Plan' : 'Create Plan',
    primaryButtonLabel: isEditing ? 'Update Plan' : 'Create Plan',
    initialName: initialPlan?.name ?? '',
    initialNotes: initialPlan?.notes ?? '',
    emptyNameMessage: 'Please provide a name for this plan',
  );

  if (details == null) return null;

  final controller = context.read<SupabaseExerciseAndRoutineController>();

  if (isEditing) {
    final updated = initialPlan.copyWith(
      name: details.name,
      notes: details.notes,
    );
    await controller.updatePlan(plan: updated);
    return updated;
  } else {
    final newPlan = RoutinePlanDto(
      name: details.name,
      notes: details.notes,
    );
    final created = await controller.savePlan(planDto: newPlan);
    return created;
  }
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
      child: RoutineLogScreen(
        id: log.id,
        isEditable: true,
        showShareOnLoad: false,
      ),
    );
  }
}

Future<void> navigateToRoutineLogEditor(
    {required BuildContext context,
    required RoutineLogArguments arguments}) async {
  final log = await showEditorBottomSheet<RoutineLogDto>(
      context: context,
      child: RoutineLogEditorScreen(
        log: arguments.log,
        mode: arguments.editorMode,
        cached: arguments.cached,
      ));
  if (log != null) {
    if (context.mounted) {
      navigateWithSlideTransition(
        context: context,
        child: RoutineLogScreen(
          id: log.id,
          isEditable: true,
          showShareOnLoad: arguments.editorMode == RoutineEditorMode.log,
        ),
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

Future<void> navigateToRoutineTemplatePreview(
    {required BuildContext context,
    required RoutineTemplateDto template}) async {
  await showEditorBottomSheet<void>(
    context: context,
    isDismissible: false, // prevent swipe-to-dismiss; match editor behavior
    builder: (context, scrollController) {
      return RoutineTemplateScreen(
        id: template.id,
        scrollController: scrollController,
      );
    },
  );
}

void navigateToRoutinePlanPreview(
    {required BuildContext context, required RoutinePlanDto plan}) {
  context.push(RoutinePlanScreen.routeName, extra: plan);
}

Future<void> navigateToRoutineLogPreview(
    {required BuildContext context,
    required RoutineLogDto log,
    bool isEditable = true,
    bool showShareOnLoad = false}) {
  return navigateWithSlideTransition(
    context: context,
    child: RoutineLogScreen(
      id: log.id,
      isEditable: isEditable,
      showShareOnLoad: showShareOnLoad,
    ),
  );
}

Future<void> navigateToExerciseHome(
    {required BuildContext context, required ExerciseDto exercise}) async {
  await showEditorBottomSheet(
      context: context, child: ExerciseHomeScreen(exercise: exercise));
}

void navigateToRoutineHome({required BuildContext context}) {
  context.push(RoutinePlansScreen.routeName);
}

Future<void> navigateToSettings({required BuildContext context}) async {
  // Only show settings if we're on the overview/home screen
  final currentRoute = GoRouterState.of(context).uri.path;
  final isOnOverview = currentRoute == Home.routeName || currentRoute == '/';

  if (!isOnOverview) {
    // Don't show settings unless on overview screen
    return;
  }

  await showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Settings',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, animation, secondaryAnimation) {
      return Stack(
        children: [
          // Blurred + dimmed background
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                color: Colors.black.withValues(alpha: 0.25),
              ),
            ),
          ),
          // Full-screen settings content
          const SettingsScreen(),
        ],
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
  );
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
