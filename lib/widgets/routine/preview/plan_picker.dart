import 'package:flutter/material.dart';

import 'package:trainware/dtos/appsync/routine_plan_dto.dart';

import '../../../../colors.dart';
import '../../buttons/opacity_button_widget_two.dart';

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
    final listTiles = plans
        .map((plan) => ListTile(
              onTap: () {
                onSelect(plan);
              },
              contentPadding: EdgeInsets.zero,
              title: Text(
                plan.name,
                style: TextStyle(fontWeight: FontWeight.w400),
              ),
            ))
        .toList();

    return plans.isNotEmpty
        ? SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                ...listTiles
              ],
            ),
          )
        : _EmptyState(onPressed: onCreatePlan ?? () {});
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
                  buttonColor: vibrantGreen))
        ],
      ),
    );
  }
}
