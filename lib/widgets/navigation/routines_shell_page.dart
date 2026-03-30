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

/// Empty routines tab: matches [CoachFeedbackFeedScreen] structure (app bar + icon + title + body).
class _RoutinesShellEmptyTab extends StatelessWidget {
  const _RoutinesShellEmptyTab({
    required this.isCoach,
    required this.bottomPad,
  });

  final bool isCoach;
  final double bottomPad;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final muted =
        (isDark ? Colors.white : Colors.black).withValues(alpha: 0.45);

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
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: FaIcon(
                        FontAwesomeIcons.clipboardList,
                        size: 48,
                        color: muted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No routine plan yet',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isCoach
                          ? 'Create a plan to add workout templates and organize training for your clients.'
                          : 'When your coach builds your plan, your workouts will appear here.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: muted,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (isCoach) ...[
                      const SizedBox(height: 28),
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
        ),
      ],
    );
  }
}
