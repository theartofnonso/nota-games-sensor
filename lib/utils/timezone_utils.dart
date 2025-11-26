import 'package:timezone/timezone.dart' as tz;

tz.TZDateTime _nextInstanceOfHour({required int hours}) {
  final DateTime now = DateTime.now();
  tz.TZDateTime scheduledDate = tz.TZDateTime.from(
    DateTime(now.year, now.month, now.day, hours, 0, 0, 0, 0),
    tz.local,
  );

  if (scheduledDate.isBefore(now)) {
    scheduledDate = scheduledDate.add(const Duration(days: 1));
  }

  return scheduledDate;
}

tz.TZDateTime nextInstanceOfHourAndWeekDay({required int hours, required int weekday}) {
  tz.TZDateTime scheduledDate = _nextInstanceOfHour(hours: hours);
  while (scheduledDate.weekday != weekday) {
    scheduledDate = scheduledDate.add(const Duration(days: 1));
  }
  return scheduledDate;
}

tz.TZDateTime nextMorningAtHour({
  required DateTime reference,
  int hour = 9,
}) {
  final referenceDate = DateTime(reference.year, reference.month, reference.day);
  final nextMorning = referenceDate.add(const Duration(days: 1));
  return tz.TZDateTime.from(
    DateTime(nextMorning.year, nextMorning.month, nextMorning.day, hour),
    tz.local,
  );
}
