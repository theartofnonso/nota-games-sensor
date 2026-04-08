/// Parses workout session timestamps from the API (Supabase / JSON).
///
/// PostgREST often returns timestamptz with `Z` or an offset. If the string has
/// no timezone, we treat it as **UTC** so naive `"2024-01-15T10:00:00"` is not
/// misread as local wall time (which would skew weekdays and reminder times).
bool workoutSessionTimestampHasExplicitZone(String raw) {
  final t = raw.trim();
  if (t.endsWith('Z') || t.endsWith('z')) return true;
  return RegExp(r'[+-]\d{2}:\d{2}(:\d{2})?$').hasMatch(t) ||
      RegExp(r'[+-]\d{4}$').hasMatch(t);
}

DateTime parseWorkoutSessionInstant(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    throw const FormatException('Empty workout session timestamp');
  }
  final d = DateTime.parse(trimmed);
  if (workoutSessionTimestampHasExplicitZone(trimmed)) {
    return d.toUtc();
  }
  return DateTime.utc(
    d.year,
    d.month,
    d.day,
    d.hour,
    d.minute,
    d.second,
    d.millisecond,
    d.microsecond,
  );
}
