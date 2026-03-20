import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainware/controllers/access_controller.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/screens/routines/routine_plan.dart';
import 'package:trainware/utils/app_privileges.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/utils/navigation_utils.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';
import 'package:trainware/widgets/navigation/app_floating_navigation_bar.dart';
import 'package:trainware/widgets/empty_states/list_empty_state.dart';

/// Shell tab: primary routine plan (first plan) with bottom nav visible.
class RoutinesShellPage extends StatelessWidget {
  const RoutinesShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SupabaseExerciseAndRoutineController>();
    context.watch<ClientOverrideController>();

    if (controller.plans.isEmpty) {
      final canCreate = AppPrivileges.canCreateManageRoutines;
      final bottomPad =
          MediaQuery.paddingOf(context).bottom + kAppFloatingNavBarReserveHeight;
      return Scaffold(
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: themeGradient(context: context),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPad),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const ListEmptyState(
                    message:
                        'No routine plan yet. Create one to add workout templates.',
                  ),
                  if (canCreate) ...[
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: OpacityButtonWidgetTwo(
                        label: 'Create routine plan',
                        onPressed: () =>
                            navigateToRoutinePlanEditor(context: context),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RoutinePlanScreen(
      id: controller.plans.first.id,
      embeddedInShell: true,
    );
  }
}
