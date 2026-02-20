import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../dtos/appsync/routine_log_dto.dart';
import '../extensions/duration_extension.dart';
import '../utils/general_utils.dart';
import '../widgets/bottom_sheets/app_bottom_sheet.dart';
import '../widgets/routine/preview/routine_log_widget.dart';
import 'navigation_utils.dart';

/// Shared calendar date logs bottom sheet. Dynamically sizes height by content
/// (header + list items or empty state), capped at 55% of screen.
/// Draggable; tapping outside dismisses.
void showCalendarDateLogsSheet({
  required BuildContext context,
  required DateTime date,
  required List<RoutineLogDto> logs,
  required String dateLabel,
  required bool isToday,
  required bool isPredicted,
  required bool showLogWorkoutButton,
}) {
  final hasLogs = logs.isNotEmpty;

  const double kHeaderHeight = 100;
  const double kListItemHeight = 72;
  const double kListItemSpacing = 12;
  const double kListPaddingVertical = 16;
  const double kEmptyStateHeight = 200;
  const double kMinSheetHeight = 320;
  const double kMaxSheetFraction = 0.55;

  final screenHeight = MediaQuery.of(context).size.height;
  final contentHeight = hasLogs
      ? kHeaderHeight +
          kListPaddingVertical +
          logs.length * (kListItemHeight + kListItemSpacing)
      : kHeaderHeight + kEmptyStateHeight;
  final preferredHeight = contentHeight.clamp(kMinSheetHeight, double.infinity);
  final maxSheetHeight =
      preferredHeight.clamp(0.0, screenHeight * kMaxSheetFraction);

  showAppBottomSheet(
    context: context,
    isDraggable: true,
    isDismissible: true,
    builder: (sheetContext, scrollController) {
      final isDarkMode = Theme.of(sheetContext).brightness == Brightness.dark;

      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateLabel,
                          style: Theme.of(sheetContext)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          DateFormat('MMMM d').format(date),
                          style: Theme.of(sheetContext)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Colors.grey.shade400,
                              ),
                        ),
                      ],
                    ),
                  ),
                  if (isToday && showLogWorkoutButton)
                    IconButton(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        logEmptyRoutine(context: context);
                      },
                      icon: FaIcon(
                        FontAwesomeIcons.circlePlus,
                        size: 22,
                        color: isDarkMode ? Colors.white : Colors.black,
                      ),
                    ),
                ],
              ),
            ),
            Flexible(
              child: hasLogs
                  ? ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final log = logs[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: RoutineLogWidget(
                            log: log,
                            trailing: log.duration().hmsAnalog(),
                            onTap: () {
                              Navigator.pop(sheetContext);
                              navigateToRoutineLogPreview(
                                context: context,
                                log: log,
                                isEditable: true,
                              );
                            },
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          isPredicted
                              ? 'This is a day you\'re likely to train based on your previous workout history.'
                              : 'No workouts logged this date',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                                    color: Colors.grey.shade400,
                                  ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      );
    },
  );
}
