import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../dtos/appsync/routine_log_dto.dart';
import '../../../utils/exercise_logs_utils.dart';
import '../../../utils/navigation_utils.dart';
import '../../../utils/string_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

class RoutineLogWidget extends StatelessWidget {
  final RoutineLogDto log;
  final String trailing;
  final bool isEditable;
  final void Function()? onTap;

  const RoutineLogWidget(
      {super.key,
      required this.log,
      required this.trailing,
      this.isEditable = true,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final completedExerciseLogsAndSets =
        loggedExercises(exerciseLogs: log.exerciseLogs);
    final totalCompletedSets = completedExerciseLogsAndSets
        .map((e) => e.sets.length)
        .fold<int>(0, (sum, len) => sum + len);

    final gradientColors = [
      Colors.grey.withValues(alpha: 0.2),
      Colors.black.withValues(alpha: 0.4),
      Colors.black.withValues(alpha: 0.5),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.15,
                  child: Image.asset(
                    'images/1k_Dissolve_Noise_Texture.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                onTap: onTap ??
                    () => navigateToRoutineLogPreview(
                        context: context, log: log, isEditable: isEditable),
                // leading: Container(
                //   width: 38,
                //   height: 38,
                //   decoration: BoxDecoration(
                //     shape: BoxShape.circle,
                //     color: Theme.of(context)
                //         .colors
                //         .vibrantAccent
                //         .withValues(alpha: 0.18),
                //     border: Border.all(
                //       color: Theme.of(context)
                //           .colors
                //           .vibrantAccent
                //           .withValues(alpha: 0.35),
                //     ),
                //   ),
                //   child: Center(
                //     child: FaIcon(
                //       FontAwesomeIcons.personWalking,
                //       color: Theme.of(context).colors.vibrantAccent,
                //       size: 18,
                //     ),
                //   ),
                // ),
                title: Text(
                  log.name,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                ),
                subtitle: Text(
                  "${completedExerciseLogsAndSets.length} ${pluralize(word: "exercise", count: completedExerciseLogsAndSets.length)} • $totalCompletedSets ${pluralize(word: "set", count: totalCompletedSets)}",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                ),
                trailing: Text(
                  trailing,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
