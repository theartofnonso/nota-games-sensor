import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:trainware/controllers/supabase_exercise_and_routine_controller.dart';
import 'package:trainware/dtos/appsync/routine_log_dto.dart';
import 'package:trainware/extensions/datetime/datetime_extension.dart';
import 'package:trainware/utils/date_utils.dart';
import 'package:trainware/utils/theme/color_extensions.dart';

class _DateViewModel {
  final DateTime dateTime;
  final DateTime selectedDateTime;
  final bool hasRoutineLog;

  _DateViewModel(
      {required this.dateTime,
      required this.selectedDateTime,
      this.hasRoutineLog = false});
}

const int _kMonthOrigin = 1000;

/// A plug‑and‑play calendar widget that shows the current week by default and toggles
/// to a month grid on tap of the header. No external [DateTime] dependency required.
class Calendar extends StatefulWidget {
  const Calendar(
      {super.key,
      this.onSelectDate,
      this.logs,
      this.onMonthChanged,
      this.initiallyExpanded = false});

  /// Fired whenever the user selects a day.
  final void Function(DateTime dateTime)? onSelectDate;
  final void Function(DateTimeRange range)? onMonthChanged;

  /// Whether the calendar should start in expanded (month) view
  final bool initiallyExpanded;

  final List<RoutineLogDto>? logs;

  @override
  State<Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<Calendar>
    with SingleTickerProviderStateMixin {
  late final DateTime
      _anchor; // today without the time component – used as the origin for paging maths
  late DateTime _selected;
  late DateTime _focused;
  late final PageController _monthCtl;
  late bool _expanded;

  late int _currentMonthWeeks;

  // ───────────────────────────  Lifecycle  ────────────────────────────

  @override
  void initState() {
    super.initState();
    _anchor = DateTime.now().withoutTime();
    _selected = _anchor;
    _focused = _selected;
    _monthCtl = PageController(initialPage: _kMonthOrigin);
    _currentMonthWeeks = _calculateWeeksInMonth(_focused);
    _expanded = widget.initiallyExpanded;

    // Trigger initial month range
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final start = DateTime(_focused.year, _focused.month, 1);
      final end = DateTime(_focused.year, _focused.month + 1, 0);
      widget.onMonthChanged?.call(DateTimeRange(start: start, end: end));
    });
  }

  // ───────────────────────────  Helpers  ────────────────────────────

  int _calculateWeeksInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final leadingNulls = firstDay.weekday - 1; // Monday‑based week
    final totalDays = leadingNulls + lastDay.day;
    return (totalDays / 7).ceil();
  }

  DateTime _mondayOf(DateTime d) => d.subtract(Duration(days: d.weekday - 1));

  DateTime _monthByIndex(int pageIndex) =>
      DateTime(_anchor.year, _anchor.month + (pageIndex - _kMonthOrigin), 1);

  void _onDateTap(DateTime d) {
    setState(() => _selected = d);
    widget.onSelectDate?.call(d);
  }

  void _toggleView() => setState(() {
        _expanded = !_expanded;
        if (!_expanded) {
          _focused = _anchor; // header shows the current month
          widget.onMonthChanged?.call(thisMonthDateRange());
        }
      });

  // ───────────────────────────  Build  ──────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        _CalendarTitleHeader(
          date: _focused,
          isExpanded: _expanded,
          onToggle: _toggleView,
          isDarkMode: isDark,
        ),
        const SizedBox(height: 10),
        const _CalendarHeader(),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          alignment: Alignment.topCenter,
          child: LayoutBuilder(
            builder: (context, constraints) {
              const double rowHeight =
                  60.0; // Adjust based on your item height + spacing
              final int rowCount = _expanded ? _currentMonthWeeks : 1;
              final double height = rowHeight * rowCount;

              return SizedBox(
                height: height,
                child: _expanded
                    ? _buildMonthPager(isDark)
                    : _buildWeekGrid(isDark),
              );
            },
          ),
        )
      ],
    );
  }

  // Week pager  ──────────────────────────────────────────────────────

// ─── ❸: new helper – a fixed grid for the current week ──────────────
  Widget _buildWeekGrid(bool isDark) {
    final monday = _mondayOf(_anchor); // always anchor‑week
    final days = List.generate(7, (i) => monday.add(Duration(days: i)));
    final logs = widget.logs ??
        context.read<SupabaseExerciseAndRoutineController>().logs;

    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(), // <— not scrollable
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: 7,
      itemBuilder: (_, i) {
        final d = days[i];
        final has = logs.any((l) => l.startTime.isSameDayMonthYear(d));
        return _Day(
          dateTime: d,
          selected: d.isSameDayMonthYear(_selected),
          currentDate: d.isSameDayMonthYear(DateTime.now()),
          hasRoutineLog: has,
          onTap: _onDateTap,
          isDarkMode: isDark,
        );
      },
    );
  }

  // Month pager  ─────────────────────────────────────────────────────

  Widget _buildMonthPager(bool isDark) {
    return PageView.builder(
      controller: _monthCtl,
      onPageChanged: (page) {
        final newMonth = _monthByIndex(page);
        setState(() {
          _focused = newMonth;
          _currentMonthWeeks = _calculateWeeksInMonth(newMonth);
        });

        // Calculate month boundaries and trigger callback
        final start = DateTime(newMonth.year, newMonth.month, 1);
        final end = DateTime(newMonth.year, newMonth.month + 1, 0);
        widget.onMonthChanged?.call(DateTimeRange(start: start, end: end));
      },
      itemBuilder: (_, page) {
        final monthStart = _monthByIndex(page);
        final grid = _generateMonthDates(monthStart);
        return _Month(
          dates: grid,
          selectedDateTime: _selected,
          onTap: _onDateTap,
          isDarkMode: isDark,
        );
      },
    );
  }

  // Utilities to build month grid  ───────────────────────────────────

  List<_DateViewModel?> _generateMonthDates(DateTime monthStart) {
    final first = DateTime(monthStart.year, monthStart.month, 1);
    final last = DateTime(monthStart.year, monthStart.month + 1, 0);
    final logs = widget.logs ??
        context.read<SupabaseExerciseAndRoutineController>().logs.where(
            (l) => l.startTime.isBetweenInclusive(from: first, to: last));

    final List<_DateViewModel?> out = [];
    for (int i = 1; i < first.weekday; i++) {
      out.add(null);
    }
    for (int d = 1; d <= last.day; d++) {
      final date = DateTime(monthStart.year, monthStart.month, d);
      final has = logs.any((l) => l.startTime.isSameDayMonthYear(date));
      out.add(_DateViewModel(
          dateTime: date, selectedDateTime: _selected, hasRoutineLog: has));
    }
    while (out.length % 7 != 0) {
      out.add(null);
    }
    return out;
  }
}

class _CalendarTitleHeader extends StatelessWidget {
  final DateTime date;
  final bool isExpanded;
  final VoidCallback onToggle;
  final bool isDarkMode;

  const _CalendarTitleHeader({
    required this.date,
    required this.isExpanded,
    required this.onToggle,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            DateFormat('MMMM yyyy').format(date),
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          FaIcon(
            isExpanded ? Icons.expand_less : Icons.expand_more,
          ),
        ],
      ),
    );
  }
}

class _CalendarHeader extends StatelessWidget {
  const _CalendarHeader();

  @override
  Widget build(BuildContext context) {
    Brightness systemBrightness = Theme.of(context).brightness;
    final isDarkMode = systemBrightness == Brightness.dark;

    return SizedBox(
      height: 25,
      child: GridView.builder(
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          childAspectRatio: 1,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: 7,
        itemBuilder: (_, index) => Text(
          ["mon", "tue", "wed", "thu", "fri", "sat", "sun"][index],
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: isDarkMode ? Colors.white70 : Colors.black54),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _Month extends StatelessWidget {
  final List<_DateViewModel?> dates;
  final DateTime selectedDateTime;
  final void Function(DateTime dateTime) onTap;
  final bool isDarkMode;

  const _Month(
      {required this.dates,
      required this.selectedDateTime,
      required this.onTap,
      required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1,
        crossAxisSpacing: 4.0,
        mainAxisSpacing: 4.0,
      ),
      itemCount: dates.length,
      itemBuilder: (_, index) => dates[index] == null
          ? const SizedBox()
          : _Day(
              dateTime: dates[index]!.dateTime,
              selected:
                  dates[index]!.dateTime.isSameDayMonthYear(selectedDateTime),
              currentDate:
                  dates[index]!.dateTime.isSameDayMonthYear(DateTime.now()),
              hasRoutineLog: dates[index]!.hasRoutineLog,
              onTap: onTap,
              isDarkMode: isDarkMode,
            ),
    );
  }
}

class _Day extends StatelessWidget {
  final DateTime dateTime;
  final bool selected;
  final bool hasRoutineLog;
  final bool currentDate;
  final void Function(DateTime dateTime) onTap;
  final bool isDarkMode;

  const _Day({
    required this.dateTime,
    required this.selected,
    required this.currentDate,
    required this.onTap,
    this.hasRoutineLog = false,
    required this.isDarkMode,
  });

  Color _getBackgroundColor(BuildContext context) => hasRoutineLog
      ? (isDarkMode
          ? Theme.of(context).colors.vibrantAccent.withValues(alpha: 0.1)
          : Theme.of(context).colors.vibrantAccent)
      : (isDarkMode
          ? Theme.of(context).colors.sapphireDark80.withValues(alpha: 0.5)
          : Colors.grey.shade200);

  Color _getTextColor(BuildContext context) => hasRoutineLog
      ? (isDarkMode ? Theme.of(context).colors.vibrantAccent : Colors.black)
      : (isDarkMode ? Colors.white : Colors.black);

  Border? _dateBorder() {
    if (selected) return Border.all(color: Colors.blueGrey, width: 2);
    if (currentDate) return Border.all(color: Colors.grey, width: 2);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(dateTime),
      child: Container(
        padding: selected ? const EdgeInsets.all(2) : null,
        decoration: BoxDecoration(
            border: _dateBorder(), borderRadius: BorderRadius.circular(2)),
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
              color: _getBackgroundColor(context),
              borderRadius: BorderRadius.circular(2)),
          child: Center(
            child: Text(
              "${dateTime.day}",
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _getTextColor(context)),
            ),
          ),
        ),
      ),
    );
  }
}
