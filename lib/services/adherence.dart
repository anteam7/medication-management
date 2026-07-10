import '../models/medication_item.dart';
import '../utils/date_key.dart';

enum DayStatus { future, noData, complete, missed }

/// Summarizes whether every medication that existed by [day] had all of its
/// assigned time slots (or the implicit "any" slot) checked off that day.
/// Days before any medication was added come back as [DayStatus.noData]
/// rather than [DayStatus.missed] — there was nothing to miss yet.
DayStatus dayStatusFor(DateTime day, List<MedicationItem> items) {
  final today = dateOnly(DateTime.now());
  final d = dateOnly(day);
  if (d.isAfter(today)) return DayStatus.future;

  final existedByThen = items.where((item) => !dateOnly(item.createdAt).isAfter(d));
  if (existedByThen.isEmpty) return DayStatus.noData;

  return missedItemsFor(d, items).isEmpty ? DayStatus.complete : DayStatus.missed;
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
