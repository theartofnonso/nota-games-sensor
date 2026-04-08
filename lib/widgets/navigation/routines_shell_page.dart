import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:trainware/app_flavor.dart';
import 'package:trainware/controllers/access_controller.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/screens/routines/routine_plan.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/utils/navigation_utils.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';
import 'package:trainware/widgets/empty_states/illustrated_empty_state.dart';
import 'package:trainware/widgets/navigation/app_floating_navigation_bar.dart';

/// Shell tab: primary routine plan (first plan) with bottom nav visible.
class RoutinesShellPage extends StatelessWidget {
  const RoutinesShellPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SupabaseExerciseAndRoutineController>();
    context.watch<ClientOverrideController>();

    if (controller.plans.isEmpty) {
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
            child: _RoutinesShellEmptyTab(
              isCoach: AppConfig.isCoach,
              bottomPad: bottomPad,
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

/// Empty routines tab: [IllustratedEmptyState] + app bar (nutrition / plan pattern).
class _RoutinesShellEmptyTab extends StatelessWidget {
  const _RoutinesShellEmptyTab({
    required this.isCoach,
    required this.bottomPad,
  });

  final bool isCoach;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppBar(
          title: const Text('Routine plan'),
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          automaticallyImplyLeading: false,
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPad),
            child: IllustratedEmptyState(
              outerVerticalPadding: 0,
              icon: FontAwesomeIcons.clipboardList,
              title: 'No routine plan yet',
              body: isCoach
                  ? 'Create a plan to add workout templates and organize training for your clients.'
                  : 'When your coach builds your plan, your workouts will appear here.',
              childBelow: isCoach
                  ? SizedBox(
                      width: double.infinity,
                      child: OpacityButtonWidgetTwo(
                        label: 'Create routine plan',
                        onPressed: () =>
                            navigateToRoutinePlanEditor(context: context),
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
