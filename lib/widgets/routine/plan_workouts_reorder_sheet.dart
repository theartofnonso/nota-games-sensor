import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import 'package:trainware/app_flavor.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/dtos/appsync/routine_plan_dto.dart';
import 'package:trainware/dtos/appsync/routine_template_dto.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';
import 'package:trainware/widgets/loading/coach_loading_overlay.dart';

Future<void> showPlanWorkoutsReorderSheet({
  required BuildContext context,
  required RoutinePlanDto plan,
  required List<RoutineTemplateDto> initialOrder,
}) {
  return showAppBottomSheet<void>(
    context: context,
    initialChildSize: 0.55,
    minChildSize: 0.38,
    maxChildSize: 0.9,
    builder: (context, scrollController) {
      return _PlanWorkoutsReorderBody(
        scrollController: scrollController,
        plan: plan,
        initialOrder: List<RoutineTemplateDto>.of(initialOrder),
      );
    },
  );
}

class _PlanWorkoutsReorderBody extends StatefulWidget {
  final ScrollController? scrollController;
  final RoutinePlanDto plan;
  final List<RoutineTemplateDto> initialOrder;

  const _PlanWorkoutsReorderBody({
    required this.scrollController,
    required this.plan,
    required this.initialOrder,
  });

  @override
  State<_PlanWorkoutsReorderBody> createState() =>
      _PlanWorkoutsReorderBodyState();
}

class _PlanWorkoutsReorderBodyState extends State<_PlanWorkoutsReorderBody> {
  late List<RoutineTemplateDto> _items;

  @override
  void initState() {
    super.initState();
    _items = List<RoutineTemplateDto>.of(widget.initialOrder);
  }

  Future<void> _save() async {
    if (!mounted) return;
    if (AppConfig.isCoach) showCoachLoadingOverlay(context);
    try {
      await context
          .read<SupabaseExerciseAndRoutineController>()
          .reorderWorkoutsInPlan(
            planId: widget.plan.id,
            orderedTemplateIds: _items.map((t) => t.id).toList(),
          );
    } finally {
      if (AppConfig.isCoach && mounted) {
        hideCoachLoadingOverlay(context);
      }
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reorder workouts',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              Text(
                widget.plan.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ReorderableListView.builder(
              scrollController: widget.scrollController,
              buildDefaultDragHandles: false,
              padding: EdgeInsets.zero,
              itemCount: _items.length,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex -= 1;
                  final moved = _items.removeAt(oldIndex);
                  _items.insert(newIndex, moved);
                });
              },
              proxyDecorator: (child, index, animation) {
                return Material(
                  type: MaterialType.transparency,
                  child: child,
                );
              },
              itemBuilder: (context, index) {
                final t = _items[index];
                return ListTile(
                  key: ValueKey<String>(t.id),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: ReorderableDragStartListener(
                    index: index,
                    child: const FaIcon(FontAwesomeIcons.gripLines, size: 20),
                  ),
                  title: Text(
                    t.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              },
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            minimum: const EdgeInsets.only(left: 20, right: 20, bottom: 16),
            child: SizedBox(
              width: double.infinity,
              child: OpacityButtonWidgetTwo(
                buttonColor: Theme.of(context).colors.vibrantAccent,
                label: 'Save order',
                onPressed: _save,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
