import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:trainware/extensions/duration_extension.dart';

import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import '../routine/preview/routine_log_widget.dart';

class CalendarLogs extends StatelessWidget {
  final DateTime dateTime;

  const CalendarLogs({super.key, required this.dateTime});

  @override
  Widget build(BuildContext context) {
    final routineLogController =
        Provider.of<SupabaseExerciseAndRoutineController>(context,
            listen: false);
    final logs =
        routineLogController.whereLogsIsSameDay(dateTime: dateTime).toList();
    final children = logs.map((log) {
      Widget widget;

      widget = RoutineLogWidget(log: log, trailing: log.duration().hmsAnalog());

      return Padding(
        padding: const EdgeInsets.only(bottom: 8.0),
        child: widget,
      );
    }).toList();

    return Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 16,
        children: children);
  }
}
