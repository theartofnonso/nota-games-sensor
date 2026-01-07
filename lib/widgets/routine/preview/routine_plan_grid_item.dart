import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';

import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import '../../../dtos/appsync/routine_plan_dto.dart';
import '../../../utils/navigation_utils.dart';
import '../../../utils/string_utils.dart';
import '../../icons/custom_icon.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

class RoutinePlanGridItemWidget extends StatelessWidget {
  final RoutinePlanDto plan;
  final double radius;
  final void Function()? onTap;

  const RoutinePlanGridItemWidget(
      {super.key, required this.plan, this.radius = 22, this.onTap});

  @override
  Widget build(BuildContext context) {
    final exerciseAndRoutineController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);

    final routineTemplates = exerciseAndRoutineController.templates
        .where((template) => template.planId == plan.id)
        .toList();

    final exerciseTemplates = routineTemplates
        .expand((routineTemplate) => routineTemplate.exerciseTemplates);
    return GestureDetector(
      onTap: onTap ??
          () => navigateToRoutinePlanPreview(context: context, plan: plan),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey.withValues(alpha: 0.2),
                  Colors.black.withValues(alpha: 0.4),
                  Colors.black.withValues(alpha: 0.5),
                ],
              ),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
            child: Stack(
              children: [
                // Texture overlay
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.15,
                    child: Image.asset(
                      'images/1k_Dissolve_Noise_Texture.jpg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                // System plan badge indicator
                if (plan.isSystemPlan)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Text(
                      'Not Athletes',
                      style: TextStyle(
                        fontFamily: 'GroutpixFlow',
                        color: Colors.blueGrey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ),
                // Content
                Padding(
                  padding: const EdgeInsets.all(16),
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
                                  color:
                                      Theme.of(context).colorScheme.secondary,
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
                      ]),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
