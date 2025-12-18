import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';
import 'package:trainware/extensions/datetime/datetime_extension.dart';
import 'package:trainware/utils/general_utils.dart';
import 'package:trainware/utils/notifications_utils.dart';
import 'package:trainware/utils/string_utils.dart';
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

    final today = DateTime.now();
    final startDate = DateTime(today.year - 1, today.month, today.day);
    final endDate = DateTime(today.year, 12, 31);

    // Group dates by month (same logic as _ContinuousCalendarGrid)
    final months = <DateTime>[];
    var currentDate = startDate;
    while (currentDate.isBefore(endDate) ||
        currentDate.isAtSameMomentAs(endDate)) {
      final monthKey = DateTime(currentDate.year, currentDate.month);
      if (months.isEmpty ||
          months.last.year != monthKey.year ||
          months.last.month != monthKey.month) {
        months.add(monthKey);
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }

    // Find which month is currently visible based on scroll offset
    double accumulatedHeight = 8.0; // ListView top padding
    DateTime? visibleMonthStart;

    for (int i = 0; i < months.length; i++) {
      final month = months[i];
      final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
      final firstDayOfMonth = DateTime(month.year, month.month, 1);
      final firstMonday = _findPreviousMonday(firstDayOfMonth);
      final leadingEmptyCells = firstDayOfMonth.difference(firstMonday).inDays;
      final daysInWeek = (daysInMonth + leadingEmptyCells) % 7;
      final trailingEmptyCells = daysInWeek == 0 ? 0 : 7 - daysInWeek;
      final totalCells = leadingEmptyCells + daysInMonth + trailingEmptyCells;
      final rows = (totalCells / 7).ceil();

      const containerPadding = 20.0 + 12.0;
      const headerHeight = 50.0;
      const headerSpacing = 16.0;
      const gridRowHeight = 60.0;
      const monthBottomPadding = 24.0;

      final monthHeight = containerPadding +
          headerHeight +
          headerSpacing +
          (rows * gridRowHeight) +
          monthBottomPadding;

      // Check if scroll offset is within this month's range
      if (scrollOffset >= accumulatedHeight &&
          scrollOffset < accumulatedHeight + monthHeight) {
        visibleMonthStart = month;
        break;
      }

      accumulatedHeight += monthHeight;
    }

    // Fallback to today's month if we couldn't determine
    visibleMonthStart ??= DateTime(today.year, today.month);

    if (_lastReportedMonthStart == null ||
        _lastReportedMonthStart!.year != visibleMonthStart.year ||
        _lastReportedMonthStart!.month != visibleMonthStart.month) {
      _lastReportedMonthStart = visibleMonthStart;
      widget.onMonthChanged?.call(visibleMonthStart);
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
    final endDate = DateTime(today.year, 12, 31);

    // Group dates by month to find the index of today's month
    final months = <DateTime>[];
    var currentDate = startDate;
    while (currentDate.isBefore(endDate) ||
        currentDate.isAtSameMomentAs(endDate)) {
      final monthKey = DateTime(currentDate.year, currentDate.month);
      if (months.isEmpty ||
          months.last.year != monthKey.year ||
          months.last.month != monthKey.month) {
        months.add(monthKey);
      }
      currentDate = currentDate.add(const Duration(days: 1));
    }

    // Find the index of the month containing today
    final todayMonth = DateTime(today.year, today.month);
    final monthIndex = months.indexWhere((month) =>
        month.year == todayMonth.year && month.month == todayMonth.month);

    if (monthIndex == -1) return;

    // Wait for the ListView to build and measure items
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      // Calculate accumulated height up to the target month
      // Each month section includes:
      // - ListView padding: 8px top (only for first item)
      // - Container padding: 20px top + 12px bottom = 32px
      // - Month header: ~50px (with padding)
      // - Header spacing: 16px
      // - Grid height: rows * ~60px per row (childAspectRatio 0.9, mainAxisSpacing 8)
      // - Month bottom padding: 24px

      double accumulatedHeight = 8.0; // ListView top padding

      for (int i = 0; i < monthIndex; i++) {
        final month = months[i];
        final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
        final firstDayOfMonth = DateTime(month.year, month.month, 1);
        final firstMonday = _findPreviousMonday(firstDayOfMonth);
        final leadingEmptyCells =
            firstDayOfMonth.difference(firstMonday).inDays;
        final daysInWeek = (daysInMonth + leadingEmptyCells) % 7;
        final trailingEmptyCells = daysInWeek == 0 ? 0 : 7 - daysInWeek;
        final totalCells = leadingEmptyCells + daysInMonth + trailingEmptyCells;
        final rows = (totalCells / 7).ceil();

        // Month section height calculation
        const containerPadding = 20.0 + 12.0; // top + bottom
        const headerHeight = 50.0;
        const headerSpacing = 16.0;
        const gridRowHeight = 60.0; // approximate based on childAspectRatio 0.9
        const monthBottomPadding = 24.0;

        final monthHeight = containerPadding +
            headerHeight +
            headerSpacing +
            (rows * gridRowHeight) +
            monthBottomPadding;
        accumulatedHeight += monthHeight;
      }

      // Ensure we don't exceed max scroll extent
      final maxExtent = _scrollController.position.maxScrollExtent;
      final targetOffset = accumulatedHeight.clamp(0.0, maxExtent);

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
    });
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

                    // Get predicted training dates until end of current year
                    final historicDates =
                        controller.logs.map((log) => log.startTime).toList();
                    final now = DateTime.now();
                    final todayStart = DateTime(now.year, now.month, now.day);
                    final endOfYear = DateTime(now.year, 12, 31);
                    final daysAhead = endOfYear.difference(todayStart).inDays;
                    final predictedDates = getPredictedTrainingDates(
                      historicDateTimes: historicDates,
                      daysAhead: daysAhead,
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

    // Group dates by month
    final months = <DateTime, List<DateTime>>{};
    var currentDate = startDate;
    while (currentDate.isBefore(endDate) ||
        currentDate.isAtSameMomentAs(endDate)) {
      final monthKey = DateTime(currentDate.year, currentDate.month);
      months.putIfAbsent(monthKey, () => []).add(currentDate);
      currentDate = currentDate.add(const Duration(days: 1));
    }

    final monthEntries = months.entries.toList();

    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        overscroll: false,
      ),
      child: ListView.builder(
        controller: scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: monthEntries.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding:
                  const EdgeInsets.only(left: 4, right: 4, top: 8, bottom: 16),
              child: Text(
                "We only show the past 12 months through the end of this year.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
              ),
            );
          }

          final monthEntry = monthEntries.elementAt(index - 1);
          final monthStart = monthEntry.key;
          final daysInMonth = monthEntry.value;

          return _MonthSection(
            monthStart: monthStart,
            daysInMonth: daysInMonth,
            selectedDate: selectedDate,
            logs: logs,
            predictedDates: predictedDates,
            onDateTap: onDateTap,
          );
        },
      ),
    );
  }
}

class _MonthSection extends StatelessWidget {
  final DateTime monthStart;
  final List<DateTime> daysInMonth;
  final DateTime selectedDate;
  final List<RoutineLogDto> logs;
  final Set<DateTime> predictedDates;
  final void Function(DateTime date) onDateTap;

  const _MonthSection({
    required this.monthStart,
    required this.daysInMonth,
    required this.selectedDate,
    required this.logs,
    required this.predictedDates,
    required this.onDateTap,
  });

  int _getMonthSessionCount() {
    return logs.where((log) {
      final dt = log.startTime;
      return dt.year == monthStart.year && dt.month == monthStart.month;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    // Find the first Monday of the month (or before if month doesn't start on Monday)
    final firstDayOfMonth = DateTime(monthStart.year, monthStart.month, 1);
    final firstMonday = _findPreviousMonday(firstDayOfMonth);

    // Calculate leading empty cells
    final leadingEmptyCells = firstDayOfMonth.difference(firstMonday).inDays;

    // Get last day of month
    final lastDayOfMonth = DateTime(monthStart.year, monthStart.month + 1, 0);
    final daysInWeek = (lastDayOfMonth.day + leadingEmptyCells) % 7;
    final trailingEmptyCells = daysInWeek == 0 ? 0 : 7 - daysInWeek;
    final totalCells =
        leadingEmptyCells + daysInMonth.length + trailingEmptyCells;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(36),
        ),
        padding: const EdgeInsets.fromLTRB(15, 20, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Month and year label inside container with session count
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.8),
                    width: 0.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('MMMM yyyy').format(monthStart),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w400,
                          ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '• ${_getMonthSessionCount()} ${pluralize(word: "Session", count: _getMonthSessionCount())}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontWeight: FontWeight.w400,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.9,
                mainAxisSpacing: 8,
                crossAxisSpacing: 4,
              ),
              itemCount: totalCells,
              itemBuilder: (context, index) {
                if (index < leadingEmptyCells ||
                    index >= leadingEmptyCells + daysInMonth.length) {
                  return const SizedBox();
                }

                final cellDate = daysInMonth[index - leadingEmptyCells];
                final hasLog = logs
                    .any((log) => log.startTime.isSameDayMonthYear(cellDate));
                final cellDateNormalized =
                    DateTime(cellDate.year, cellDate.month, cellDate.day);
                final isPredicted = predictedDates.contains(cellDateNormalized);
                final isSelected = cellDate.isSameDayMonthYear(selectedDate);
                final isToday = cellDate.isSameDayMonthYear(DateTime.now());

                return _DateCell(
                  date: cellDate,
                  hasLog: hasLog,
                  isPredicted: isPredicted,
                  isSelected: isSelected,
                  isToday: isToday,
                  showMonthLabel: false,
                  onTap: () => onDateTap(cellDate),
                );
              },
            ),
          ],
        ),
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
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(6),
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
                      width: 28,
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
                              fontSize: 14,
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
