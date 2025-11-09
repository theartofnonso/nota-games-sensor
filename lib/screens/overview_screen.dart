import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tracker_app/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:tracker_app/extensions/duration_extension.dart';
import 'package:tracker_app/widgets/routine/preview/routine_log_widget.dart';

import '../widgets/backgrounds/trkr_loading_screen.dart';
import '../widgets/calendar/infinite_calendar.dart';

class OverviewScreen extends StatefulWidget {
  static const routeName = '/overview_screen';

  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    if (_loading) return TRKRLoadingScreen(action: _hideLoadingScreen);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: InfiniteCalendar(
        onDateTap: (date) => _showLogsForDate(context, date),
      ),
    );
  }

  void _showLogsForDate(BuildContext context, DateTime date) {
    final controller = context.read<SupabaseExerciseAndRoutineController>();
    final logs = controller.whereLogsIsSameDay(dateTime: date).toList();

    if (logs.isEmpty) {
      // No logs for this day - don't show bottom sheet
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          final isDarkMode = Theme.of(context).brightness == Brightness.dark;

          return Container(
            decoration: BoxDecoration(
              color: isDarkMode ? Color(0xFF1A1F2E) : Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header with date
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Text(
                    DateFormat('EEEE, MMMM d, y').format(date),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const Divider(),
                // Scrollable log list
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: logs.length,
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: RoutineLogWidget(
                          log: log,
                          trailing: log.duration().hmsAnalog(),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _hideLoadingScreen() {
    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }
}
