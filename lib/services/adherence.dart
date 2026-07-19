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
