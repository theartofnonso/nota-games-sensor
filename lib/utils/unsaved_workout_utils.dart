import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';
import 'package:trainware/dtos/viewmodels/routine_log_arguments.dart';
import 'package:trainware/enums/routine_editor_type_enums.dart';
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
              'You have a workout session ready to resume:',
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
            SizedBox(
              width: double.infinity,
              child: OpacityButtonWidgetTwo(
                label: 'Resume workout',
                buttonColor: Theme.of(context).colors.vibrantAccent,
                showArrowRight: false,
                onPressed: resumeTraining,
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
