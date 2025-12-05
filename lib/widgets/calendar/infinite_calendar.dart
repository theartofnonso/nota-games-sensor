import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';
import 'package:trainware/extensions/datetime/datetime_extension.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/utils/notifications_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

/// Infinite scrollable calendar with continuous date flow
/// Dates flow across month boundaries without line breaks
class InfiniteCalendar extends StatefulWidget {
  final void Function(DateTime date)? onDateTap;
  final void Function(DateTime visibleMonthStart)? onMonthChanged;

  const InfiniteCalendar({
    super.key,
    this.onDateTap,
    this.onMonthChanged,
  });

  @override
  State<InfiniteCalendar> createState() => _InfiniteCalendarState();
}

class _InfiniteCalendarState extends State<InfiniteCalendar> {
  final ScrollController _scrollController = ScrollController();
  DateTime _selectedDate = DateTime.now();
  bool _hasScrolledToToday = false;
  bool _showScrollToTodayButton = false;
  double? _todayScrollOffset;

  /// Tracks the last month we reported via [onMonthChanged] so we only
  /// notify when the visible month actually changes.
  DateTime? _lastReportedMonthStart;

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
    if (!mounted) return;

    final currentOffset = _scrollController.offset;

    // Always update visible month based on scroll position.
    _updateVisibleMonth(currentOffset);

    // Only handle "Back to Today" button visibility once we know where
    // today's row is.
    if (_todayScrollOffset == null) return;

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

  void _updateVisibleMonth(double scrollOffset) {
    if (widget.onMonthChanged == null) return;

    // Mirror the same date range logic used by _ContinuousCalendarGrid.
    final today = DateTime.now();
    final startDate = DateTime(today.year - 1, today.month, today.day);
    final firstMonday = _findPreviousMonday(startDate);

    // Use the same approximate row height as in _scrollToCurrentDate.
    const approximateRowHeight = 60.0;
    if (approximateRowHeight <= 0) return;

    // Calculate today's row index for comparison
    final daysToToday = today.difference(firstMonday).inDays;
    final todayRowIndex = daysToToday ~/ 7;
    final todayScrollOffset = todayRowIndex * approximateRowHeight;

    // Estimate which row is currently at the top of the viewport.
    final rawRowIndex = (scrollOffset / approximateRowHeight).floor();
    final rowIndex = rawRowIndex < 0 ? 0 : rawRowIndex;

    // If we're at or near today's position, use today's month directly
    final isNearToday =
        (scrollOffset - todayScrollOffset).abs() < approximateRowHeight;
    final visibleMonthStart = isNearToday
        ? DateTime(today.year, today.month)
        : _calculateMonthFromRow(rowIndex, firstMonday);

    if (_lastReportedMonthStart == null ||
        _lastReportedMonthStart!.year != visibleMonthStart.year ||
        _lastReportedMonthStart!.month != visibleMonthStart.month) {
      _lastReportedMonthStart = visibleMonthStart;
      widget.onMonthChanged?.call(visibleMonthStart);
    }
  }

  DateTime _calculateMonthFromRow(int rowIndex, DateTime firstMonday) {
    // Each row represents a full week (7 days).
    // Use the middle of the viewport to determine the visible month
    // This handles cases where a week spans two months (e.g., week starting Nov 25 includes Dec 1)
    final viewportCenterDays = rowIndex * 7 + 3; // Middle of the week (day 3-4)
    final centerDate = firstMonday.add(Duration(days: viewportCenterDays));
    return DateTime(centerDate.year, centerDate.month);
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

    // Ensure the initial visible month overlay matches where we scrolled.
    _updateVisibleMonth(targetOffset);

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

                    // Get predicted training dates for next 7 days
                    final historicDates =
                        controller.logs.map((log) => log.startTime).toList();
                    final predictedDates = getPredictedTrainingDates(
                      historicDateTimes: historicDates,
                      daysAhead: 7,
                    );

                    return _ContinuousCalendarGrid(
                      scrollController: _scrollController,
                      selectedDate: _selectedDate,
                      logs: controller.logs,
                      predictedDates: predictedDates,
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
              bottom: 130,
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
  final Set<DateTime> predictedDates;
  final void Function(DateTime date) onDateTap;

  const _ContinuousCalendarGrid({
    required this.scrollController,
    required this.selectedDate,
    required this.logs,
    required this.predictedDates,
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
          final cellDateNormalized =
              DateTime(cellDate.year, cellDate.month, cellDate.day);
          final isPredicted = predictedDates.contains(cellDateNormalized);
          final isSelected = cellDate.isSameDayMonthYear(selectedDate);
          final isToday = cellDate.isSameDayMonthYear(DateTime.now());
          final isFirstOfMonth = cellDate.day == 1;

          return _DateCell(
            date: cellDate,
            hasLog: hasLog,
            isPredicted: isPredicted,
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

class _DateCell extends StatefulWidget {
  final DateTime date;
  final bool hasLog;
  final bool isPredicted;
  final bool isSelected;
  final bool isToday;
  final bool showMonthLabel;
  final VoidCallback onTap;

  const _DateCell({
    required this.date,
    required this.hasLog,
    required this.isPredicted,
    required this.isSelected,
    required this.isToday,
    required this.showMonthLabel,
    required this.onTap,
  });

  @override
  State<_DateCell> createState() => _DateCellState();
}

class _DateCellState extends State<_DateCell>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // Only animate if predicted and not hasLog
    if (widget.isPredicted && !widget.hasLog) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_DateCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPredicted != oldWidget.isPredicted ||
        widget.hasLog != oldWidget.hasLog) {
      if (widget.isPredicted && !widget.hasLog) {
        _animationController.repeat(reverse: true);
      } else {
        _animationController.stop();
        _animationController.reset();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    Color backgroundColor;
    if (widget.hasLog) {
      backgroundColor = isDarkMode
          ? Theme.of(context).colors.vibrantAccent.withValues(alpha: 0.1)
          : Theme.of(context).colors.vibrantAccent;
    } else {
      backgroundColor = Colors.transparent;
    }

    // Check if this is today
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final thisDate =
        DateTime(widget.date.year, widget.date.month, widget.date.day);
    final isToday = thisDate.isAtSameMomentAs(today);

    Color textColor;
    if (isToday) {
      // Today: always white
      textColor = Colors.white;
    } else if (widget.hasLog) {
      textColor =
          isDarkMode ? Theme.of(context).colors.vibrantAccent : Colors.black;
    } else if (widget.isPredicted) {
      // Predicted days: white text (badge will show green indicator)
      textColor = Colors.white;
    } else if (widget.showMonthLabel) {
      textColor = Colors.white;
    } else {
      // Past/future dates: reduced opacity
      textColor = Colors.white.withValues(alpha: 0.3);
    }

    Border? border;
    if (widget.isSelected) {
      if (widget.hasLog) {
        border = Border.all(
          color: isDarkMode
              ? Theme.of(context).colors.vibrantAccent
              : Theme.of(context).colors.vibrantAccent.withValues(alpha: 0.8),
          width: 2,
        );
      } else {
        border = Border.all(
          color: Colors.white,
          width: 2,
        );
      }
    }

    Widget dateCell = GestureDetector(
      onTap: widget.onTap,
      child: Center(
        child: Container(
          padding: widget.isSelected ? const EdgeInsets.all(2) : null,
          decoration: BoxDecoration(
            border: border,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Stack(
            children: [
              Container(
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
                    if (widget.showMonthLabel)
                      Text(
                        DateFormat('MMM').format(widget.date),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: widget.hasLog || widget.isPredicted
                                  ? textColor
                                  : Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 8,
                            ),
                      ),
                    SizedBox(
                      width: 32,
                      child: Text(
                        '${widget.date.day}',
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                              color: textColor,
                              fontWeight: widget.hasLog || widget.isPredicted
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              fontSize: 16,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              // Green badge for predicted days
              if (widget.isPredicted && !widget.hasLog)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colors.vibrantAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    // Apply pulse animation for predicted days
    if (widget.isPredicted && !widget.hasLog) {
      return AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Opacity(
              opacity: 0.7 + (_pulseAnimation.value - 0.8) * 0.3,
              child: dateCell,
            ),
          );
        },
      );
    }

    return dateCell;
  }
}
