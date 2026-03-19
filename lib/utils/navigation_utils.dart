import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:trainware/controllers/access_controller.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/screens/editors/routine_log_editor_screen.dart';
import 'package:trainware/screens/exercise/history/exercise_home_screen.dart';
import 'package:trainware/screens/preferences/account_settings_screen.dart';
import 'package:trainware/screens/home.dart';
import 'package:trainware/screens/chat/chat_screen.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/utils/app_privileges.dart';
import 'package:trainware/utils/dialog_utils.dart';
import 'package:trainware/widgets/loading/coach_loading_overlay.dart';

import '../dtos/appsync/exercise_dto.dart';
import '../dtos/appsync/routine_log_dto.dart';
import '../dtos/appsync/routine_plan_dto.dart';
import '../dtos/appsync/routine_template_dto.dart';
import '../dtos/viewmodels/routine_log_arguments.dart';
import '../dtos/viewmodels/routine_plan_arguments.dart';
import '../dtos/viewmodels/routine_template_arguments.dart';
import '../enums/routine_editor_type_enums.dart';
import '../screens/editors/routine_template_editor_screen.dart';
import '../screens/logs/coach_feedback_feed_screen.dart';
import '../screens/logs/routine_log_screen.dart';
import '../screens/routines/routine_plan.dart';
import '../screens/video/incoming_call_screen.dart';
import '../screens/routines/routine_template_screen.dart';
import '../utils/name_notes_bottom_sheet.dart';
import '../widgets/bottom_sheets/app_bottom_sheet.dart';
import 'editor_bottom_sheet.dart';

Future<RoutineTemplateDto?> navigateToRoutineTemplateEditor(
    {required BuildContext context,
    required RoutineTemplateArguments arguments}) async {
  final template = await showAppBottomSheet<RoutineTemplateDto>(
    context: context,
    isDraggable: true,
    isDismissible:
        false, // Prevent auto-dismiss - PopScope will handle via GestureDetector
    enableDrag: true,
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
    compact: true,
  );

  if (details == null) return null;

  final controller = context.read<SupabaseExerciseAndRoutineController>();
  if (AppConfig.isCoach) showCoachLoadingOverlay(context);
  try {
    if (isEditing) {
      final updated = initialPlan.copyWith(
        name: details.name,
        notes: details.notes,
      );
      await controller.updatePlan(plan: updated);
      if (!context.mounted) return null;
      return updated;
    } else {
      final newPlan = RoutinePlanDto(
        name: details.name,
        notes: details.notes,
      );
      final created = await controller.savePlan(planDto: newPlan);
      if (!context.mounted) return null;
      return created;
    }
  } finally {
    if (AppConfig.isCoach) hideCoachLoadingOverlay(context);
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
  // Create a callback for barrier taps when in edit mode
  Future<bool> Function()? onBarrierTap;
  if (arguments.editorMode == RoutineEditorMode.edit) {
    onBarrierTap = () async {
      // Show confirmation dialog when barrier is tapped in edit mode
      return await confirmDiscardChangesBottomSheet(
        context: context,
        title: 'Leave editor?',
        description: 'Are you sure you want to leave?',
      );
    };
  }

  final log = await showEditorBottomSheet<RoutineLogDto>(
    context: context,
    isDismissible: arguments.editorMode ==
        RoutineEditorMode.log, // Only dismissible in log mode, not edit mode
    enableDrag: true,
    onBarrierTap: onBarrierTap,
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
  await navigateWithSlideTransition(
    context: context,
    child: RoutineTemplateScreen(id: template.id),
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

Future<void> navigateToSettings({required BuildContext context}) async {
  final path = GoRouterState.of(context).uri.path;
  final isShellTab =
      path == '/' || path == Home.routeName || path == '/coach';

  if (!isShellTab) {
    return;
  }

  if (!context.mounted) return;

  await Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      pageBuilder: (ctx, animation, secondaryAnimation) =>
          const AccountSettingsScreen(),
      transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    ),
  );
}

/// Opens chat as a slide-up route with app-bar close (not a shell tab).
Future<void> navigateToChat({
  required BuildContext context,
}) async {
  final accessController = context.read<ClientOverrideController>();

  if (!AppConfig.isCoach && !AppPrivileges.isProWithCoach) {
    if (context.mounted) {
      showSnackbar(
        context: context,
        message:
            'Messaging with your coach is available on the Pro plan with a coach.',
      );
    }
    return;
  }

  if (AppConfig.isCoach &&
      (accessController.selectedClientId == null ||
          accessController.selectedClientId!.isEmpty)) {
    if (context.mounted) {
      showSnackbar(
        context: context,
        message: 'Select a client from the Clients tab to open chat.',
      );
    }
    return;
  }

  if (!AppConfig.isCoach && (accessController.coachId ?? '').isEmpty) {
    if (context.mounted) {
      showSnackbar(
        context: context,
        message: 'Connect with a coach to start messaging.',
      );
    }
    return;
  }

  String clientUserId = '';
  String clientName = '';
  String coachId = '';
  String coachName = '';

  if (AppConfig.isCoach) {
    clientUserId = accessController.selectedClientId ?? '';
    clientName = accessController.selectedClientName ?? '';
    coachId = accessController.userId ?? '';
  } else {
    coachId = accessController.coachId ?? '';
    coachName = accessController.coachName ?? '';
    clientUserId = accessController.userId ?? '';
  }

  if (!context.mounted) return;

  await Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      pageBuilder: (ctx, animation, secondaryAnimation) => ChatScreen(
        coachId: coachId,
        coachName: coachName,
        clientUserId: clientUserId,
        clientName: clientName,
        embeddedInShell: false,
      ),
      transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    ),
  );
}

/// Coach feedback feed (Pro clients with a coach). Slide-up with app-bar close.
Future<void> navigateToCoachFeedbackFeed({
  required BuildContext context,
}) async {
  if (!AppPrivileges.isProWithCoach) {
    if (context.mounted) {
      showSnackbar(
        context: context,
        message:
            'Coach feedback is available when you are on Pro with a coach.',
      );
    }
    return;
  }
  if (!context.mounted) return;

  await Navigator.of(context, rootNavigator: true).push<void>(
    PageRouteBuilder<void>(
      pageBuilder: (ctx, animation, secondaryAnimation) =>
          const CoachFeedbackFeedScreen(),
      transitionsBuilder: (ctx, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    ),
  );
}

/// Primary routine plan (first plan) as a slide-up route with close.
Future<void> navigateToPrimaryRoutinePlan({
  required BuildContext context,
}) async {
  final access = context.read<ClientOverrideController>();
  if (AppConfig.isCoach && !access.hasSelectedClient) {
    if (context.mounted) {
      showSnackbar(
        context: context,
        message: 'Select a client to view their routine plan.',
      );
    }
    return;
  }

  final controller = context.read<SupabaseExerciseAndRoutineController>();
  if (controller.plans.isEmpty) {
    final canCreate = AppPrivileges.canCreateManageRoutines;
    if (canCreate) {
      await navigateToRoutinePlanEditor(context: context);
    } else if (context.mounted) {
      showSnackbar(
        context: context,
        message: 'Your coach hasn’t assigned a routine plan yet.',
      );
    }
    return;
  }

  if (!context.mounted) return;
  await navigateWithSlideTransition(
    context: context,
    child: RoutinePlanScreen(id: controller.plans.first.id),
    rootNavigator: true,
  );
}

/// Create a screen on demand
Future<T?> navigateWithSlideTransition<T>({
  required BuildContext context,
  required Widget child,
  bool rootNavigator = false,
}) {
  final route = PageRouteBuilder<T>(
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

  return Navigator.of(context, rootNavigator: rootNavigator).push<T>(route);
}

/// Shows the incoming call screen (from FCM push). Caller must be authenticated.
void navigateToIncomingCall({
  required BuildContext context,
  required String callerId,
  required String callerName,
  required String channelName,
}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      fullscreenDialog: true,
      opaque: false,
      pageBuilder: (_, __, ___) => IncomingCallScreen(
        callerId: callerId,
        callerName: callerName,
        channelName: channelName,
      ),
      transitionsBuilder: (_, animation, __, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        final tween = Tween(begin: begin, end: end)
            .chain(CurveTween(curve: Curves.easeOutCubic));
        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    ),
  );
}
