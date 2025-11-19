import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';
import 'package:trainware/dtos/viewmodels/routine_log_arguments.dart';
import 'package:trainware/enums/routine_editor_type_enums.dart';
import 'package:trainware/shared_prefs.dart';
import 'package:trainware/utils/dialog_utils.dart';
import 'package:trainware/utils/navigation_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';
import 'package:trainware/widgets/bottom_sheets/app_bottom_sheet.dart';
import 'package:trainware/widgets/buttons/opacity_button_widget_two.dart';

import '../controllers/supabase_exercise_and_routine_controller.dart';

/// Shows the "unsaved workout" bottom sheet and forces the user
/// to either discard, retry sync, or continue the cached session.
Future<void> showUnsavedWorkoutBottomSheet(BuildContext context) async {
  final cache = SharedPrefs().routineLog;
  if (cache.isEmpty) return;

  try {
    final json = jsonDecode(cache);
    final routineLog = RoutineLogDto.fromJson(json: json);

    void discardCachedSession() {
      Navigator.of(context).pop(); // Close bottom sheet

      // Clear the cached workout
      SharedPrefs().remove(key: SharedPrefs().routineLogKey);

      // Notify user
      showSnackbar(
        context: context,
        message: 'Workout discarded',
      );
    }

    Future<void> retryCachedSession() async {
      Navigator.of(context).pop(); // Close bottom sheet

      final controller = context.read<SupabaseExerciseAndRoutineController>();

      // Check if this log already exists in the database
      final existingLog = controller.logWhereId(id: routineLog.id);

      if (existingLog != null) {
        // Log already exists - just clear the cache
        SharedPrefs().remove(key: SharedPrefs().routineLogKey);

        showSnackbar(
          context: context,
          message: 'Workout was already saved!',
        );
        return;
      }

      // Try to save the cached workout
      final savedLog = await controller.saveLog(logDto: routineLog);

      // Clear cache ONLY if save succeeded
      if (savedLog != null) {
        SharedPrefs().remove(key: SharedPrefs().routineLogKey);

        showSnackbar(
          context: context,
          message: 'Session saved successfully!',
        );
      } else {
        // Save failed - keep cache so user can retry later
        showSnackbar(
          context: context,
          message: 'Failed to sync. Please try again later.',
        );
      }
    }

    void continueTraining() {
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
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  color: Theme.of(context).colors.vibrantAccent,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Unsaved Workout',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'You have a workout session that failed to sync:',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    routineLog.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${routineLog.exerciseLogs.length} exercises • ${DateFormat('MMM d, y').format(routineLog.startTime)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OpacityButtonWidgetTwo(
                    label: 'Discard',
                    buttonColor: Colors.red,
                    onPressed: discardCachedSession,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OpacityButtonWidgetTwo(
                    label: 'Retry Sync',
                    buttonColor: Theme.of(context).colors.vibrantAccent,
                    onPressed: retryCachedSession,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OpacityButtonWidgetTwo(
                label: 'Continue Training',
                buttonColor: Theme.of(context).colors.vibrantAccent,
                onPressed: continueTraining,
              ),
            ),
          ],
        ),
      ),
    );
  } catch (e) {
    debugPrint('[Retry] Error showing retry sheet: $e');
  }
}
