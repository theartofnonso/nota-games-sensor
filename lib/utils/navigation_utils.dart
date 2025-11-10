import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tracker_app/screens/editors/exercise_editor_screen.dart';
import 'package:tracker_app/screens/exercise/history/exercise_home_screen.dart';
import 'package:tracker_app/screens/logs/routine_log_summary_screen.dart';
import 'package:tracker_app/screens/preferences/settings_screen.dart';

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
import '../screens/editors/routine_plan_editor_screen.dart';
import '../screens/editors/routine_template_editor_screen.dart';
import '../screens/logs/routine_log_screen.dart';
import '../screens/routines/routine_plan.dart';
import '../screens/routines/routine_plans_screen.dart';
import '../screens/routines/routine_template_screen.dart';

Future<ExerciseDto?> navigateToExerciseEditor(
    {required BuildContext context, ExerciseEditorArguments? arguments}) async {
  final exercise = await context.push(ExerciseEditorScreen.routeName, extra: arguments) as ExerciseDto?;
  return exercise;
}

Future<RoutineTemplateDto?> navigateToRoutineTemplateEditor(
    {required BuildContext context, required RoutineTemplateArguments arguments}) async {
  final template = await context.push(RoutineTemplateEditorScreen.routeName, extra: arguments) as RoutineTemplateDto?;
  return template;
}

Future<RoutinePlanDto?> navigateToRoutinePlanEditor(
    {required BuildContext context, RoutinePlanArguments? arguments}) async {
  final plan = await navigateWithSlideTransition(
    context: context,
    child: RoutinePlanEditorScreen(plan: arguments?.plan),
  ) as RoutinePlanDto?;
  return plan;
}

void navigateToPastRoutineLogEditor({required BuildContext context, required PastRoutineLogArguments arguments}) async {
  final log = await navigateWithSlideTransition(
    context: context,
    child: PastRoutineLogEditorScreen(log: arguments.log),
  );
  if (log != null) {
    if (context.mounted) {
      navigateWithSlideTransition(
        context: context,
        child: RoutineLogScreen(id: (log as RoutineLogDto).id, showSummary: true, isEditable: true),
      );
    }
  }
}

Future<void> navigateToRoutineLogEditor({required BuildContext context, required RoutineLogArguments arguments}) async {
  final log = await navigateWithSlideTransition(
    context: context,
    child: RoutineLogEditorScreen(log: arguments.log, mode: arguments.editorMode),
  ) as RoutineLogDto?;
  if (log != null) {
    if (context.mounted) {
      navigateWithSlideTransition(
        context: context,
        child: RoutineLogScreen(id: log.id, showSummary: true, isEditable: true),
      );
    }
  }
}

Future<RoutineLogDto?> navigateToRoutineEditorAndReturnLog(
    {required BuildContext context, required RoutineLogArguments arguments}) async {
  final log = await context.push(RoutineLogEditorScreen.routeName, extra: arguments) as RoutineLogDto?;
  return log;
}

void navigateToRoutineTemplatePreview({required BuildContext context, required RoutineTemplateDto template}) {
  context.push(RoutineTemplateScreen.routeName, extra: template);
}

void navigateToRoutinePlanPreview({required BuildContext context, required RoutinePlanDto plan}) {
  context.push(RoutinePlanScreen.routeName, extra: plan);
}

void navigateToRoutineLogPreview({required BuildContext context, required RoutineLogDto log, bool isEditable = true}) {
  navigateWithSlideTransition(
    context: context,
    child: RoutineLogScreen(id: log.id, showSummary: false, isEditable: isEditable),
  );
}

Future<void> navigateToExerciseHome({required BuildContext context, required ExerciseDto exercise}) async {
  await context.push(ExerciseHomeScreen.routeName, extra: exercise);
}

void navigateToShareableScreen({required BuildContext context, required RoutineLogDto log}) {
  context.push(RoutineLogSummaryScreen.routeName, extra: log);
}

void navigateToRoutineHome({required BuildContext context}) {
  context.push(RoutinePlansScreen.routeName);
}

Future<void> navigateToSettings({required BuildContext context}) async {
  await context.push(SettingsScreen.routeName);
}

/// Create a screen on demand
Future navigateWithSlideTransition({required BuildContext context, required Widget child}) {
  final route = PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      const begin = Offset(0.0, 1.0);
      const end = Offset.zero;
      const curve = Curves.ease;
      final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
      final offsetAnimation = animation.drive(tween);
      return SlideTransition(
        position: offsetAnimation,
        child: child,
      );
    },
  );

  return Navigator.of(context).push(route);
}
