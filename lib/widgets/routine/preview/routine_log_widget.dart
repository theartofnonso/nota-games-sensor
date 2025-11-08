import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../dtos/appsync/routine_log_dto.dart';
import '../../../utils/exercise_logs_utils.dart';
import '../../../utils/navigation_utils.dart';
import '../../../utils/string_utils.dart';
import '../../list_tile.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

class RoutineLogWidget extends StatelessWidget {
  final RoutineLogDto log;
  final String trailing;
  final bool isEditable;

  const RoutineLogWidget({super.key, required this.log, required this.trailing, this.isEditable = true});

  @override
  Widget build(BuildContext context) {

    final completedExerciseLogsAndSets = loggedExercises(exerciseLogs: log.exerciseLogs);

    return ThemeListTile(
      child: ListTile(
        onTap: () => navigateToRoutineLogPreview(context: context, log: log, isEditable: isEditable),
        leading: FaIcon(
          FontAwesomeIcons.personWalking,
          color: Theme.of(context).colors.vibrantAccent,
          size: 28,
        ),
        title: Text(log.name, overflow: TextOverflow.ellipsis),
        subtitle: Text(
            "${completedExerciseLogsAndSets.length} ${pluralize(word: "exercise", count: completedExerciseLogsAndSets.length)}"),
        trailing: Text(trailing),
      ),
    );
  }
}
