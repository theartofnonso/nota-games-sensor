import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:tracker_app/extensions/datetime/datetime_extension.dart';

import 'package:tracker_app/controllers/supabase_exercise_and_routine_controller.dart';
import '../../utils/general_utils.dart';
import '../../widgets/empty_states/no_list_empty_state.dart';
import '../../widgets/routine/preview/routine_log_widget.dart';

class RoutineLogsScreen extends StatelessWidget {
  static const routeName = '/routine_logs_screen';

  final DateTime dateTime;

  const RoutineLogsScreen({super.key, required this.dateTime});

  @override
  Widget build(BuildContext context) {
    final routineLogsForMonth =
        Provider.of<SupabaseExerciseAndRoutineController>(context, listen: true)
            .whereLogsIsSameMonth(dateTime: dateTime);

    final logs = routineLogsForMonth
        .sorted((a, b) => b.createdAt.compareTo(a.createdAt));

    final month = dateTime.formattedFullMonth();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBackgroundColor(context: context),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: Text("$month Strength Training".toUpperCase()),
        leading: IconButton(
            icon: const FaIcon(FontAwesomeIcons.squareXmark, size: 28),
            onPressed: Navigator.of(context).pop),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: themeGradient(context: context),
        ),
        child: SafeArea(
          bottom: false,
          minimum: const EdgeInsets.all(10.0),
          child: Column(
            children: [
              logs.isNotEmpty
                  ? Expanded(
                      child: ListView.separated(
                          padding: const EdgeInsets.only(bottom: 150),
                          itemBuilder: (BuildContext context, int index) {
                            final log = logs[index];
                            return RoutineLogWidget(
                                log: log,
                                trailing: log.createdAt.durationSinceOrDate());
                          },
                          separatorBuilder: (BuildContext context, int index) =>
                              Divider(color: Colors.transparent),
                          itemCount: logs.length),
                    )
                  : Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10.0),
                        child: const NoListEmptyState(
                            message:
                                "It might feel quiet now, but your logged workouts will soon appear here."),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
