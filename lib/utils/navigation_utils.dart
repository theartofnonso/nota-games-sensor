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
import 'package:trainware/utils/coach_mapping_utils.dart';
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
import 'shell_tab_paths.dart';
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
  if (!AppConfig.isCoach) {
    showSnackbar(
      context: context,
      message: 'Only coaches can edit routine plan details.',
    );
    return null;
  }

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

  if (!context.mounted) return null;
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
    if (AppConfig.isCoach) {
      hideCoachLoadingOverlay(context);
    }
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
        rootNavigator: true,
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

Future<void> navigateToRoutineTemplatePreview({
  required BuildContext context,
  required RoutineTemplateDto template,
  bool embeddedInShell = false,
}) async {
  if (embeddedInShell) {
    if (!context.mounted) return;
    context.go('/routine_template/${template.id}');
    return;
  }
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
    rootNavigator: true,
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
  final isShellTab = path == '/' ||
      path == Home.routeName ||
      path == '/coach' ||
      path == kShellRoutinesPath ||
      isShellRoutineTemplatePath(path) ||
      path == CoachFeedbackFeedScreen.routeName ||
      path == AccountSettingsScreen.routeName;

  if (!isShellTab) {
    return;
  }

  if (!context.mounted) return;
  context.go(AccountSettingsScreen.routeName);
}

/// Opens the dedicated one-to-one chat route via go_router.
Future<void> navigateToChat({
  required BuildContext context,
}) async {
  if (!AppConfig.supportsAgoraChat) return;
  final accessController = context.read<ClientOverrideController>();

  if (!AppConfig.isCoach && !AppPrivileges.isProWithCoach) {
    if (context.mounted) {
      showSnackbar(
        context: context,
        message:
            'Subscribe from the home screen to message your coach.',
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

  String clientUserId = '';
  String clientName = '';
  String coachId = '';
  String coachName = '';

  if (AppConfig.isCoach) {
    clientUserId = accessController.selectedClientId ?? '';
    clientName = accessController.selectedClientName ?? '';
    coachId = accessController.userId ?? '';
  } else {
    coachId = (accessController.coachId ?? '').trim();
    coachName = (accessController.coachName ?? '').trim();
    clientUserId = accessController.userId ?? '';

    // [MainShellScaffold] sets coach async; user may open chat before it runs.
    // Re-fetch assignment so assigned clients are not blocked by stale memory.
    if (coachId.isEmpty && clientUserId.isNotEmpty) {
      final coachData = await fetchCoachForClient(clientUserId);
      if (coachData != null) {
        final resolvedId = (coachData['coachId'] ?? '').trim();
        if (resolvedId.isNotEmpty) {
          coachName = (coachData['coachName'] ?? '').trim();
          accessController.setCoachData(
            coachId: resolvedId,
            coachName: coachName,
          );
          coachId = resolvedId;
        }
      }
    }

    if (coachId.isEmpty) {
      if (context.mounted) {
        showSnackbar(
          context: context,
          message: 'Connect with a coach to start messaging.',
        );
      }
      return;
    }
  }

  if (!context.mounted) return;
  final chatUri = Uri(
    path: ChatScreen.routeName,
    queryParameters: <String, String>{
      'coachId': coachId,
      'coachName': coachName,
      'clientUserId': clientUserId,
      'clientName': clientName,
    },
  );
  await context.push(chatUri.toString());
}

/// Coach feedback feed (Pro clients with a coach). Shell tab with bottom nav.
Future<void> navigateToCoachFeedbackFeed({
  required BuildContext context,
}) async {
  if (!AppPrivileges.isProWithCoach) {
    if (context.mounted) {
      showSnackbar(
        context: context,
        message:
            'Subscribe from the home screen to see coach feedback.',
      );
    }
    return;
  }
  if (!context.mounted) return;
  context.go(CoachFeedbackFeedScreen.routeName);
}

/// Primary routine plan (first plan) as a fade route with close.
Future<void> navigateToPrimaryRoutinePlan({
  required BuildContext context,
}) async {
  if (AppConfig.isClient && !AppPrivileges.isProWithCoach) {
    if (context.mounted) {
      showSnackbar(
        context: context,
        message: 'Subscribe from the home screen to access your routines.',
      );
    }
    return;
  }
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
  if (!context.mounted) return;

  if (controller.plans.isEmpty) {
    final canCreate = AppPrivileges.canCreateManageRoutines;
    context.go(kShellRoutinesPath);
    if (!canCreate && context.mounted) {
      showSnackbar(
        context: context,
        message: 'Your coach will create a routine plan for you.',
      );
    }
    return;
  }

  context.go(kShellRoutinesPath);
}

/// Fade transition (matches shell tab [CustomTransitionPage] in [main.dart]).
Future<T?> navigateWithFadeTransition<T>({
  required BuildContext context,
  required Widget child,
  bool rootNavigator = false,
}) {
  final route = PageRouteBuilder<T>(
    pageBuilder: (context, animation, secondaryAnimation) => child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );

  return Navigator.of(context, rootNavigator: rootNavigator).push<T>(route);
}

/// Create a screen on demand (slide up)
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
///
/// [callerImageUrl] caller’s photo URL from FCM; empty/absent = no background image.
void navigateToIncomingCall({
  required BuildContext context,
  required String callerId,
  required String callerName,
  required String channelName,
  String? callerImageUrl,
}) {
  if (!AppConfig.supportsVideoCalls) return;
  Navigator.of(context).push(
    PageRouteBuilder(
      fullscreenDialog: true,
      opaque: false,
      pageBuilder: (_, __, ___) => IncomingCallScreen(
        callerId: callerId,
        callerName: callerName,
        channelName: channelName,
        callerImageUrl: callerImageUrl,
      ),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ),
  );
}
