import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import 'package:tracker_app/controllers/supabase_exercise_and_routine_controller.dart';
import '../../../dtos/appsync/routine_plan_dto.dart';
import '../../../utils/navigation_utils.dart';
import '../../../utils/string_utils.dart';
import '../../icons/custom_icon.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

class RoutinePlanGridItemWidget extends StatelessWidget {
  final RoutinePlanDto plan;
  final double radius;
  final void Function()? onTap;

  const RoutinePlanGridItemWidget(
      {super.key, required this.plan, this.radius = 12, this.onTap});

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    final exerciseAndRoutineController =
        Provider.of<SupabaseExerciseAndRoutineController>(context, listen: false);

    final routineTemplates = exerciseAndRoutineController.templates
        .where((template) => template.planId == plan.id)
        .toList();

    final exerciseTemplates = routineTemplates
        .expand((routineTemplate) => routineTemplate.exerciseTemplates);
    return GestureDetector(
      onTap: onTap ?? () => navigateToRoutinePlanPreview(context: context, plan: plan),
      child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: isDarkMode ? Theme.of(context).colors.sapphireDark80 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade400,
                width: 1,
              )),
          child: Column(
              spacing: 12,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                Text(
                  plan.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 3,
                ),
                Column(
                  spacing: 6,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      children: [
                        CustomIcon(
                          FontAwesomeIcons.personWalking,
                          color: Theme.of(context).colors.vibrantAccent,
                          width: 20,
                          height: 20,
                          iconSize: 10.5,
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        Text(
                          "${exerciseTemplates.length} ${pluralize(word: "Exercise", count: exerciseTemplates.length)}",
                          style: Theme.of(context).textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ),
                    Wrap(
                      children: [
                        CustomIcon(
                          FontAwesomeIcons.hashtag,
                          color: Theme.of(context).colorScheme.secondary,
                          width: 20,
                          height: 20,
                          iconSize: 10.5,
                        ),
                        const SizedBox(
                          width: 6,
                        ),
                        Text(
                          "${routineTemplates.length} ${pluralize(word: "Session", count: routineTemplates.length)}",
                          style: Theme.of(context).textTheme.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 2,
                        ),
                      ],
                    ),
                  ],
                )
              ])),
    );
  }
}
