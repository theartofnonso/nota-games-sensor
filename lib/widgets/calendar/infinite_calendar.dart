import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tracker_app/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:tracker_app/dtos/appsync/routine_log_dto.dart';
import 'package:tracker_app/extensions/datetime/datetime_extension.dart';
import 'package:tracker_app/utils/general_utils.dart';
import 'package:tracker_app/utils/theme/color_extensions.dart';

/// Infinite scrollable calendar with continuous date flow
/// Dates flow across month boundaries without line breaks
class InfiniteCalendar extends StatefulWidget {
  final void Function(DateTime date)? onDateTap;

  const InfiniteCalendar({super.key, this.onDateTap});

  @override
  State<InfiniteCalendar> createState() => _InfiniteCalendarState();
}

class _InfiniteCalendarState extends State<InfiniteCalendar> {
  final ScrollController _scrollController = ScrollController();
  DateTime _selectedDate = DateTime.now();
  bool _hasScrolledToToday = false;
  bool _showScrollToTodayButton = false;
  double? _todayScrollOffset;

  @override
  void initState() {
    super.initState();
    // Add scroll listener to detect when user scrolls away from today
    _scrollController.addListener(_onScroll);

    // Auto-scroll to current date position after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Add a small delay to ensure the grid is fully rendered
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _scrollToCurrentDate();
        }
      });
    });
  }

  void _onScroll() {
    if (!mounted || _todayScrollOffset == null) return;

    final currentOffset = _scrollController.offset;
    final threshold =
        200.0; // Show button if scrolled more than 200 pixels away

    final isAwayFromToday =
        (currentOffset - _todayScrollOffset!).abs() > threshold;

    if (isAwayFromToday != _showScrollToTodayButton) {
      setState(() {
        _showScrollToTodayButton = isAwayFromToday;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToCurrentDate() {
    if (!_scrollController.hasClients) return;

    final today = DateTime.now();
    final startDate = DateTime(today.year - 1, today.month, today.day);
    final firstMonday = _findPreviousMonday(startDate);

    // Calculate days from first Monday to today
    final daysToToday = today.difference(firstMonday).inDays;

    // Calculate which row today is in
    final rowIndex = daysToToday ~/ 7;

    // Calculate scroll offset (approximate row height)
    // childAspectRatio = 0.9, mainAxisSpacing = 8
    // We'll use an approximate row height
    final approximateRowHeight = 60.0;
    final scrollOffset = rowIndex * approximateRowHeight;

    // Ensure we don't exceed max scroll extent
    final maxExtent = _scrollController.position.maxScrollExtent;
    final targetOffset = scrollOffset.clamp(0.0, maxExtent);

    // Save today's scroll position for comparison
    _todayScrollOffset = targetOffset;

    // Animate to position for smoother scrolling
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  DateTime _findPreviousMonday(DateTime date) {
    final daysToSubtract = date.weekday - 1;
    return date.subtract(Duration(days: daysToSubtract));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: themeGradient(context: context),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _DaysOfWeekHeader(),
              Expanded(
                child: Consumer<SupabaseExerciseAndRoutineController>(
                  builder: (context, controller, _) {
                    // Trigger scroll after data loads (only once)
                    if (!_hasScrolledToToday &&
                        !controller.isLoading &&
                        controller.logs.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted && !_hasScrolledToToday) {
                          Future.delayed(const Duration(milliseconds: 100), () {
                            if (mounted) {
                              _scrollToCurrentDate();
                              _hasScrolledToToday = true;
                            }
                          });
                        }
                      });
                    }

                    return _ContinuousCalendarGrid(
                      scrollController: _scrollController,
                      selectedDate: _selectedDate,
                      logs: controller.logs,
                      onDateTap: (date) {
                        setState(() => _selectedDate = date);
                        widget.onDateTap?.call(date);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          // Floating "Back to Today" button
          if (_showScrollToTodayButton)
            Positioned(
              bottom: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _scrollToCurrentDate,
                      borderRadius: BorderRadius.circular(28),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const FaIcon(
                              FontAwesomeIcons.calendarDay,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Today',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DaysOfWeekHeader extends StatelessWidget {
  const _DaysOfWeekHeader();

  @override
  Widget build(BuildContext context) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: days
            .map((day) => Expanded(
                  child: Center(
                    child: Text(
                      day.toLowerCase(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w300,
                            fontSize: 16,
                          ),
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

class _ContinuousCalendarGrid extends StatelessWidget {
  final ScrollController scrollController;
  final DateTime selectedDate;
  final List<RoutineLogDto> logs;
  final void Function(DateTime date) onDateTap;

  const _ContinuousCalendarGrid({
    required this.scrollController,
    required this.selectedDate,
    required this.logs,
    required this.onDateTap,
  });

  @override
  Widget build(BuildContext context) {
    // Show from this time last year to end of current year
    final today = DateTime.now();
    final startDate = DateTime(today.year - 1, today.month, today.day);
    final endDate = DateTime(today.year, 12, 31); // End of current year
    final totalDays = endDate.difference(startDate).inDays + 1;

    final firstMonday = _findPreviousMonday(startDate);
    final leadingEmptyCells = startDate.difference(firstMonday).inDays;
    final totalCells = leadingEmptyCells + totalDays;

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        overscroll: false,
      ),
      child: GridView.builder(
        controller: scrollController,
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 0.9,
          mainAxisSpacing: 8,
          crossAxisSpacing: 4,
        ),
        itemCount: totalCells,
        itemBuilder: (context, index) {
          final cellDate = firstMonday.add(Duration(days: index));
          if (cellDate.isBefore(startDate) || cellDate.isAfter(endDate)) {
            return const SizedBox();
          }

          final hasLog =
              logs.any((log) => log.startTime.isSameDayMonthYear(cellDate));
          final isSelected = cellDate.isSameDayMonthYear(selectedDate);
          final isToday = cellDate.isSameDayMonthYear(DateTime.now());
          final isFirstOfMonth = cellDate.day == 1;

          return _DateCell(
            date: cellDate,
            hasLog: hasLog,
            isSelected: isSelected,
            isToday: isToday,
            showMonthLabel: isFirstOfMonth,
            onTap: () => onDateTap(cellDate),
          );
        },
      ),
    );
  }

  DateTime _findPreviousMonday(DateTime date) {
    final daysToSubtract = date.weekday - 1;
    return date.subtract(Duration(days: daysToSubtract));
  }
}

class _DateCell extends StatelessWidget {
  final DateTime date;
  final bool hasLog;
  final bool isSelected;
  final bool isToday;
  final bool showMonthLabel;
  final VoidCallback onTap;

  const _DateCell({
    required this.date,
    required this.hasLog,
    required this.isSelected,
    required this.isToday,
    required this.showMonthLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final backgroundColor = hasLog
        ? (isDarkMode
            ? Theme.of(context).colors.vibrantAccent.withValues(alpha: 0.1)
            : Theme.of(context).colors.vibrantAccent)
        : Colors.transparent;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisDate = DateTime(date.year, date.month, date.day);
    final daysDifference = thisDate.difference(today).inDays;

    double opacity;
    if (hasLog) {
      opacity = 1.0;
    } else if (showMonthLabel) {
      opacity = 1.0;
    } else if (daysDifference == 0) {
      opacity = 1.0;
    } else if (daysDifference > 0 && daysDifference <= 7) {
      opacity = 0.9 - (daysDifference * 0.6 / 7);
    } else {
      opacity = 0.3;
    }

    final textColor = hasLog
        ? (isDarkMode ? Theme.of(context).colors.vibrantAccent : Colors.black)
        : Colors.white.withValues(alpha: opacity);

    Border? border;
    if (isSelected) {
      if (hasLog) {
        border = Border.all(
          color: isDarkMode
              ? Theme.of(context).colors.vibrantAccent
              : Theme.of(context).colors.vibrantAccent.withValues(alpha: 0.8),
          width: 2,
        );
      } else {
        border = Border.all(
          color: Colors.white.withValues(alpha: opacity),
          width: 2,
        );
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Center(
        child: Container(
          padding: isSelected ? const EdgeInsets.all(2) : null,
          decoration: BoxDecoration(
            border: border,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showMonthLabel)
                  Text(
                    DateFormat('MMM').format(date),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: hasLog ? textColor : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 8,
                        ),
                  ),
                SizedBox(
                  width: 32,
                  child: Text(
                    '${date.day}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: textColor,
                          fontWeight:
                              hasLog ? FontWeight.bold : FontWeight.w500,
                          fontSize: 16,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
