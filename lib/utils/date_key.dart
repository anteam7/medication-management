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

/// Whole calendar days from [from] to [to] (negative if [to] is earlier).
int daysBetween(DateTime from, DateTime to) =>
    dateOnly(to).difference(dateOnly(from)).inDays;

/// D-day label counting from [start] to today, e.g. "D+15" once 15 days
/// have passed, or "D-3" if [start] is 3 days in the future.
String dDayLabel(DateTime start) {
  final diff = daysBetween(start, DateTime.now());
  return diff >= 0 ? 'D+$diff' : 'D$diff';
}
