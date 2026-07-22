import '../models/medication_item.dart';
import '../utils/date_key.dart';

enum DayStatus { future, noData, pending, complete, missed }

/// Summarizes whether every medication that existed by [day] had all of its
/// assigned time slots (or the implicit "any" slot) checked off that day.
/// Days before any medication was added come back as [DayStatus.noData]
/// rather than [DayStatus.missed] — there was nothing to miss yet. Today
/// counts as [DayStatus.pending] (not missed) until everything is checked
/// off — a dose that can still be taken hasn't been missed yet.
DayStatus dayStatusFor(DateTime day, List<MedicationItem> items) {
  final today = dateOnly(DateTime.now());
  final d = dateOnly(day);
  if (d.isAfter(today)) return DayStatus.future;

  final existedByThen = items.where((item) => !dateOnly(item.createdAt).isAfter(d));
  if (existedByThen.isEmpty) return DayStatus.noData;

  if (missedItemsFor(d, items).isEmpty) return DayStatus.complete;
  return d == today ? DayStatus.pending : DayStatus.missed;
}

/// Medications that existed by [day] but weren't fully completed that day
/// (missing a completion for at least one of their assigned time slots).
List<MedicationItem> missedItemsFor(DateTime day, List<MedicationItem> items) {
  final d = dateOnly(day);
  final key = dateKey(d);

  return items.where((item) {
    if (dateOnly(item.createdAt).isAfter(d)) return false;
    final slots = item.timeSlots.isEmpty ? const [anySlotKey] : item.timeSlots.map((s) => s.name);
    final dayCompletions = item.completions[key] ?? const {};
    return slots.any((slotKey) => !dayCompletions.containsKey(slotKey));
  }).toList();
}

/// Per-medication taken/missed flags for [day], in the same order as
/// [items] — `true` if that medication was fully completed that day. Only
/// includes medications that existed by [day] yet (so days before a
/// medication was added don't count it as missed). Used to draw one pill
/// icon per medication on the calendar, capped to whatever fits a day cell.
List<bool> dailyStatusFlags(DateTime day, List<MedicationItem> items) {
  final d = dateOnly(day);
  final key = dateKey(d);

  return items.where((item) => !dateOnly(item.createdAt).isAfter(d)).map((item) {
    final slots = item.timeSlots.isEmpty ? const [anySlotKey] : item.timeSlots.map((s) => s.name);
    final dayCompletions = item.completions[key] ?? const {};
    return slots.every((slotKey) => dayCompletions.containsKey(slotKey));
  }).toList();
}

/// Medications that existed by [day] and had every assigned time slot (or
/// the implicit "any" slot) checked off that day — the complement of
/// [missedItemsFor], used to show a full 복용함/복용 안 함 breakdown rather
/// than just the missed list.
List<MedicationItem> takenItemsFor(DateTime day, List<MedicationItem> items) {
  final d = dateOnly(day);
  final key = dateKey(d);

  return items.where((item) {
    if (dateOnly(item.createdAt).isAfter(d)) return false;
    final slots = item.timeSlots.isEmpty ? const [anySlotKey] : item.timeSlots.map((s) => s.name);
    final dayCompletions = item.completions[key] ?? const {};
    return slots.every((slotKey) => dayCompletions.containsKey(slotKey));
  }).toList();
}

/// True when every slot assigned to [item] (or just the "any" slot) was
/// checked off on [day] — the single-item version of [dailyStatusFlags].
bool _isFullyCompletedOn(MedicationItem item, DateTime day) {
  final slots = item.timeSlots.isEmpty ? const [anySlotKey] : item.timeSlots.map((s) => s.name);
  final dayCompletions = item.completions[dateKey(day)] ?? const {};
  return slots.every((slotKey) => dayCompletions.containsKey(slotKey));
}

/// [item]'s taken/expected ratio across its course — from [MedicationItem.
/// courseStartDate] (falling back to [MedicationItem.createdAt] when unset)
/// up to its [MedicationItem.courseEndDate] or today, whichever is earlier.
/// Returns null when not a single day of the course has elapsed yet, so
/// callers can show "아직 데이터 없음" instead of a misleading 0%.
double? adherenceRateFor(MedicationItem item, {DateTime? asOf}) {
  final today = dateOnly(asOf ?? DateTime.now());
  final start = dateOnly(item.courseStartDate ?? item.createdAt);
  final rawEnd = dateOnly(item.courseEndDate ?? today);
  final end = rawEnd.isAfter(today) ? today : rawEnd;
  if (end.isBefore(start)) return null;

  final slots = item.timeSlots.isEmpty ? const [anySlotKey] : item.timeSlots.map((s) => s.name);
  int taken = 0;
  int total = 0;
  for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
    final dayCompletions = item.completions[dateKey(d)] ?? const {};
    for (final slotKey in slots) {
      total++;
      if (dayCompletions.containsKey(slotKey)) taken++;
    }
  }
  if (total == 0) return null;
  return taken / total;
}

/// Total number of individual dose completions recorded for [item] from its
/// start date up to [asOf] (default today) — how many times it's actually
/// been taken. Meant for medications with no defined end date, where a
/// percentage doesn't mean much (there's no "whole" to divide by) but a
/// running count does.
int totalTakenCountFor(MedicationItem item, {DateTime? asOf}) {
  final today = dateOnly(asOf ?? DateTime.now());
  final start = dateOnly(item.courseStartDate ?? item.createdAt);
  if (today.isBefore(start)) return 0;

  int count = 0;
  for (var d = start; !d.isAfter(today); d = d.add(const Duration(days: 1))) {
    count += item.completions[dateKey(d)]?.length ?? 0;
  }
  return count;
}

/// Consecutive fully-completed days counting back from [asOf] (default
/// today). A not-yet-finished today is simply skipped rather than treated
/// as a break — a dose still due later today hasn't been missed yet, so it
/// shouldn't zero out a streak built on prior days.
int currentStreakFor(MedicationItem item, {DateTime? asOf}) {
  final today = dateOnly(asOf ?? DateTime.now());
  final start = dateOnly(item.courseStartDate ?? item.createdAt);

  var d = today;
  if (!_isFullyCompletedOn(item, d)) {
    d = d.subtract(const Duration(days: 1));
  }

  int streak = 0;
  while (!d.isBefore(start) && _isFullyCompletedOn(item, d)) {
    streak++;
    d = d.subtract(const Duration(days: 1));
  }
  return streak;
}

/// True once [item]'s course has reached its end date — items with no
/// [MedicationItem.courseEndDate] (chronic/indefinite medications) never
/// "complete", they're just ongoing.
bool isCourseCompleted(MedicationItem item, {DateTime? asOf}) {
  final end = item.courseEndDate;
  if (end == null) return false;
  final today = dateOnly(asOf ?? DateTime.now());
  return !today.isBefore(dateOnly(end));
}

/// Total whole days in [item]'s course (inclusive of both ends) — only
/// meaningful when it has a [MedicationItem.courseEndDate].
int courseDayCount(MedicationItem item) {
  final start = dateOnly(item.courseStartDate ?? item.createdAt);
  final end = dateOnly(item.courseEndDate!);
  return daysBetween(start, end) + 1;
}

/// Which day of its course [item] is currently on (1-based), clamped to
/// [courseDayCount] so a course that's already ended still reads as "day
/// N of N" instead of overshooting.
int courseElapsedDay(MedicationItem item, {DateTime? asOf}) {
  final start = dateOnly(item.courseStartDate ?? item.createdAt);
  final today = dateOnly(asOf ?? DateTime.now());
  final elapsed = daysBetween(start, today) + 1;
  final total = courseDayCount(item);
  return elapsed.clamp(1, total);
}
