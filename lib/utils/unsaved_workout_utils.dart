import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';
import 'package:trainware/dtos/viewmodels/routine_log_arguments.dart';
import 'package:trainware/enums/routine_editor_type_enums.dart';
import 'package:trainware/extensions/duration_extension.dart';
import 'package:trainware/shared_prefs.dart';
import 'package:trainware/utils/navigation_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';

/// Shows the "unsaved workout" bottom sheet and lets the user
/// resume the cached session.
Future<void> showUnsavedWorkoutBottomSheet(BuildContext context) async {
  final cache = SharedPrefs().routineLog;
  if (cache.isEmpty) return;

  try {
    final json = jsonDecode(cache);
    final routineLog = RoutineLogDto.fromJson(json: json);

    void resumeTraining() {
      Navigator.of(context).pop(); // Close bottom sheet

      final arguments = RoutineLogArguments(
        log: routineLog,
        editorMode: RoutineEditorMode.log,
        cached: true,
      );
      navigateToRoutineLogEditor(context: context, arguments: arguments);
    }

    showAppBottomSheet(
      context: context,
      isScrollControlled: false,
      child: _UnsavedWorkoutBottomSheetContent(
        routineLog: routineLog,
        onResume: resumeTraining,
      ),
    );
  } catch (e) {
    debugPrint('[Retry] Error showing retry sheet: $e');
  }
}

class _UnsavedWorkoutBottomSheetContent extends StatefulWidget {
  final RoutineLogDto routineLog;
  final VoidCallback onResume;

  const _UnsavedWorkoutBottomSheetContent({
    required this.routineLog,
    required this.onResume,
  });

  @override
  State<_UnsavedWorkoutBottomSheetContent> createState() =>
      _UnsavedWorkoutBottomSheetContentState();
}

class _UnsavedWorkoutBottomSheetContentState
    extends State<_UnsavedWorkoutBottomSheetContent> {
  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _elapsed = DateTime.now().difference(widget.routineLog.startTime);
    if (_elapsed.isNegative) {
      _elapsed = Duration.zero;
    }

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed = DateTime.now().difference(widget.routineLog.startTime);
        if (_elapsed.isNegative) {
          _elapsed = Duration.zero;
        }
      });
    });
  }

  String _formatElapsedDuration(Duration duration) {
    return duration.inHours >= 1 ? duration.hmsDigital() : duration.msDigital();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.cloud_off_rounded,
                color: theme.colors.vibrantAccent,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Unsaved Workout',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'You have a workout session ready to resume:',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.routineLog.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.routineLog.exerciseLogs.length} exercises • ${DateFormat('MMM d, y').format(widget.routineLog.startTime)}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    _formatElapsedDuration(_elapsed),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 240,
              child: OpacityButtonWidgetTwo(
                label: 'Resume workout',
                buttonColor: theme.colors.vibrantAccent,
                solidBackground: true,
                showArrowRight: false,
                onPressed: widget.onResume,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
