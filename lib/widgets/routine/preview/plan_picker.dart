import 'package:flutter/material.dart';

import 'package:trainware/dtos/appsync/routine_plan_dto.dart';

import '../../../../colors.dart';
import '../../buttons/opacity_button_widget_two.dart';
import 'routine_plan_grid_item.dart';

class PlanPicker extends StatelessWidget {
  final String title;
  final List<RoutinePlanDto> plans;
  final void Function(RoutinePlanDto plan) onSelect;
  final VoidCallback? onCreatePlan;

  const PlanPicker({
    super.key,
    required this.title,
    required this.plans,
    required this.onSelect,
    this.onCreatePlan,
  });

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) {
      return _EmptyState(onPressed: onCreatePlan ?? () {});
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.only(top: 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.85,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: plans.length,
            itemBuilder: (context, index) {
              final plan = plans[index];
              return RoutinePlanGridItemWidget(
                plan: plan,
                onTap: () => onSelect(plan),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onPressed;

  const _EmptyState({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 16),
          Text(
            "No workout plans yet",
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            "Create your first plan to get started",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white54,
                ),
          ),
          const SizedBox(height: 24),
          SizedBox(
              width: double.infinity,
              child: OpacityButtonWidgetTwo(
                  onPressed: onPressed,
                  label: "Create a workout plan",
                  buttonColor: vibrantGreen,
                  solidBackground: true))
        ],
      ),
    );
  }
}
