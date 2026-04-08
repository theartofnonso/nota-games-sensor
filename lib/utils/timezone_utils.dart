import 'package:flutter/foundation.dart';
import 'package:flutter_native_timezone/flutter_native_timezone.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

bool _timeZoneDataInitialized = false;
Future<void>? _ensureLocalTimezoneFuture;

/// Initializes timezone data and sets [tz.local] from the device, once per process.
/// Call from app startup before any [zonedSchedule]; scheduling code should
/// `await` this too so late calls are safe if startup order changes.
Future<void> ensureLocalTimezoneConfigured() {
  return _ensureLocalTimezoneFuture ??= _configureLocalTimezoneOnce();
}

Future<void> _configureLocalTimezoneOnce() async {
  if (!_timeZoneDataInitialized) {
    tz_data.initializeTimeZones();
    _timeZoneDataInitialized = true;
  }

  try {
    final timeZoneName = await FlutterNativeTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));
  } catch (e, st) {
    debugPrint('[Timezone] getLocalTimezone failed: $e\n$st');
    _setLocalLocationFromDeviceOffsetOrUtc();
  }
}

/// When IANA name lookup fails, approximate using [DateTime.now().timeZoneOffset]
/// mapped to `Etc/GMT±N` (nearest hour). Falls back to UTC if that fails.
void _setLocalLocationFromDeviceOffsetOrUtc() {
  try {
    final minutes = DateTime.now().timeZoneOffset.inMinutes;
    final roundedHours =
        ((minutes + (minutes >= 0 ? 30 : -30)) ~/ 60).clamp(-14, 14);
    if (roundedHours == 0) {
      tz.setLocalLocation(tz.UTC);
      debugPrint('[Timezone] Using UTC (zero offset from device)');
      return;
    }
    final name = roundedHours > 0
        ? 'Etc/GMT-$roundedHours'
        : 'Etc/GMT+${-roundedHours}';
    tz.setLocalLocation(tz.getLocation(name));
    debugPrint('[Timezone] Using offset fallback location: $name');
  } catch (e, st) {
    debugPrint('[Timezone] Offset fallback failed: $e\n$st; using UTC');
    tz.setLocalLocation(tz.UTC);
  }
}

tz.TZDateTime _nextInstanceOfHour({required int hours, int minutes = 0}) {
  final DateTime now = DateTime.now();
  tz.TZDateTime scheduledDate = tz.TZDateTime.from(
    DateTime(now.year, now.month, now.day, hours, minutes, 0, 0, 0),
    tz.local,
  );

  if (scheduledDate.isBefore(now)) {
    scheduledDate = scheduledDate.add(const Duration(days: 1));
  }

  return scheduledDate;
}

tz.TZDateTime nextInstanceOfHourAndWeekDay({
  required int hours,
  required int weekday,
  int minutes = 0,
}) {
  tz.TZDateTime scheduledDate =
      _nextInstanceOfHour(hours: hours, minutes: minutes);
  while (scheduledDate.weekday != weekday) {
    scheduledDate = scheduledDate.add(const Duration(days: 1));
  }
  return scheduledDate;
}

/// Local weekday and clock time after applying [offset] to a recurring training
/// slot on [trainingWeekday] (1–7, Monday = 1) at [trainingHour]:[trainingMinute].
/// Used to schedule weekly notifications (e.g. nutrition nudges) relative to the
/// predicted session without reimplementing prediction logic.
({int weekday, int hour, int minute}) offsetFromWeeklyTrainingSlot({
  required int trainingWeekday,
  required int trainingHour,
  required int trainingMinute,
  required Duration offset,
}) {
  // Anchor on a known Monday so weekday arithmetic is stable.
  final anchorMonday = DateTime(2025, 1, 6);
  final daysFromMonday = (trainingWeekday - DateTime.monday + 7) % 7;
  final day = anchorMonday.add(Duration(days: daysFromMonday));
  final at = DateTime(
    day.year,
    day.month,
    day.day,
    trainingHour,
    trainingMinute,
  );
  final shifted = at.add(offset);
  return (
    weekday: shifted.weekday,
    hour: shifted.hour,
    minute: shifted.minute,
  );
}

tz.TZDateTime nextMorningAtHour({
  required DateTime reference,
  int hour = 9,
}) {
  final referenceDate =
      DateTime(reference.year, reference.month, reference.day);
  final nextMorning = referenceDate.add(const Duration(days: 1));
  return tz.TZDateTime.from(
    DateTime(nextMorning.year, nextMorning.month, nextMorning.day, hour),
    tz.local,
  );
}
