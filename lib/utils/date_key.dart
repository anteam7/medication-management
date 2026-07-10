/// Formats a date as a stable yyyy-MM-dd key, used to index per-day
/// completion records regardless of time zone or time-of-day.
String dateKey(DateTime d) {
  final y = d.year.toString().padLeft(4, '0');
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}

String todayKey() => dateKey(DateTime.now());

/// Strips the time-of-day component so dates can be compared purely by
/// calendar day.
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
