import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trainware/extensions/datetime/datetime_extension.dart';
import 'package:trainware/utils/date_utils.dart';

void main() {
  group('yearToDateTimeRange', () {
    test('Returns a range from start of the given year to the given date', () {
      final date = DateTime(2022, 5, 15, 10, 30).withoutTime();
      final result = yearToDateTimeRange(datetime: date);

      expect(result.start, DateTime(2022, 1, 1));
      expect(result.end, DateTime(2022, 5, 15));
    });

    test('Works on a date early in the year', () {
      final date = DateTime(2022, 1, 1, 5, 0).withoutTime();
      final result = yearToDateTimeRange(datetime: date);

      expect(result.start, DateTime(2022, 1, 1));
      expect(result.end, DateTime(2022, 1, 1));
    });

    test('Works on a date late in the year', () {
      final date = DateTime(2022, 12, 31, 23, 59).withoutTime();
      final result = yearToDateTimeRange(datetime: date);

      expect(result.start, DateTime(2022, 1, 1));
      expect(result.end, DateTime(2022, 12, 31));
    });
  });

  group('theLastYearDateTimeRange', () {
    test('Returns a range from one year ago to today', () {
      // We consider now truncated to withoutTime
      final now = DateTime.now().withoutTime();
      final result = theLastYearDateTimeRange();

      // The start should be now - 365 days
      final expectedStart = now.subtract(const Duration(days: 365));
      final then = DateTime(expectedStart.year, expectedStart.month, 1);

      expect(result.start, then);
      expect(result.end, now);
    });
  });

  test('Generates weekly ranges from Monday to Sunday', () {
    // Let's pick a range: 2023-01-01 (Sunday) to 2023-01-31 (Tuesday)
    // Our function should align to the Monday of the week containing start date.
    // 2023-01-01 is a Sunday, Monday of that week is 2022-12-26
    final start = DateTime(2023, 1, 1);
    final end = DateTime(2023, 1, 31);
    final weeks =
        generateWeeksInRange(range: DateTimeRange(start: start, end: end));

    // The first week should start Monday, December 26, 2022 and run to Sunday, January 1, 2023
    expect(weeks.first.start, DateTime(2022, 12, 26));
    expect(weeks.first.end, DateTime(2023, 1, 1));

    // Subsequent weeks should follow in 7-day increments
    // Let's just check a few
    expect(weeks[1].start, DateTime(2023, 1, 2));
    expect(weeks[1].end, DateTime(2023, 1, 8));

    // The last week should extend beyond 2023-01-31
    expect(weeks.last.end, DateTime(2023, 2, 5));
  });

  test('Generates month ranges correctly', () {
    // Let's pick a range: 2023-01-15 to 2023-03-10
    // The first month range should start at 2023-01-01 and end at 2023-01-31
    // The second month range should start at 2023-02-01 and end at 2023-02-28 (non-leap year)
    // The third month range should start at 2023-03-01 and end at 2023-03-31
    // NOTE: The code as given does NOT truncate the end if it goes beyond range.end
    //       It just prints the result. If you want to adjust months that surpass the end date,
    //       you'd need to modify your code accordingly. As of now, it returns full months.

    final start = DateTime(2023, 1, 15);
    final end = DateTime(2023, 3, 10);
    final months =
        generateMonthsInRange(range: DateTimeRange(start: start, end: end));

    // months should include:
    // 2023-01-01 to 2023-01-31
    // 2023-02-01 to 2023-02-28
    // 2023-03-01 to 2023-03-31

    expect(months.length, 3);

    expect(months[0].start, DateTime(2023, 1, 1));
    expect(months[0].end, DateTime(2023, 1, 31));

    expect(months[1].start, DateTime(2023, 2, 1));
    expect(months[1].end, DateTime(2023, 2, 28));

    expect(months[2].start, DateTime(2023, 3, 1));
    expect(months[2].end, DateTime(2023, 3, 31));
  });

  group('thisMonthDateRange', () {
    test('Returns date range for this month', () {
      final now = DateTime.now();
      final startOfThisMonth = DateTime(now.year, now.month, 1);
      final endOfThisMonth =
          DateTime(now.year, now.month + 1, 0); // last day of this month

      final range = thisMonthDateRange();

      expect(range.start, startOfThisMonth);
      expect(range.end, endOfThisMonth);
    });

    test('Allows custom end date', () {
      final now = DateTime.now();
      final customEndDate = DateTime(now.year, now.month, 15);
      final startOfThisMonth = DateTime(now.year, now.month, 1);

      final range = thisMonthDateRange(endDate: customEndDate);

      expect(range.start, startOfThisMonth);
      expect(range.end, customEndDate);
    });
  });
}
