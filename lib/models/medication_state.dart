import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/medication_store.dart';
import '../utils/date_key.dart';
import 'meal_timing.dart';
import 'medication_item.dart';
import 'time_slot.dart';

class MedicationState extends ChangeNotifier {
  final MedicationStore _store;
  MedicationState(this._store);

  List<MedicationItem> items = [];
  bool isLoaded = false;

  Future<void> load() async {
    items = await _store.load();
    isLoaded = true;
    notifyListeners();
  }

  static String _slotKey(TimeSlot? slot) => slot?.name ?? anySlotKey;

  bool isCompletedForSlot(MedicationItem item, TimeSlot? slot) =>
      item.completions[todayKey()]?.containsKey(_slotKey(slot)) ?? false;

  /// True when every slot assigned to [item] (or just the "any" slot, for
  /// medications with no specific time-of-day) has been checked off today.
  bool isFullyCompletedToday(MedicationItem item) {
    final slots = item.timeSlots.isEmpty ? [null] : item.timeSlots.map((s) => s as TimeSlot?);
    return slots.every((s) => isCompletedForSlot(item, s));
  }

  Future<void> addItem({
    required String name,
    XFile? referencePhoto,
    Set<TimeSlot> timeSlots = const {},
    MealTiming? mealTiming,
    DateTime? receivedDate,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    String? photoPath;
    if (referencePhoto != null) {
      photoPath = await _store.savePhoto(referencePhoto, prefix: 'ref_$id');
    }

    items.add(MedicationItem(
      id: id,
      name: trimmed,
      referencePhotoPath: photoPath,
      timeSlots: timeSlots,
      mealTiming: mealTiming,
      receivedDate: receivedDate,
    ));
    notifyListeners();
    await _store.save(items);
  }

  Future<void> editItem(
    String id, {
    String? newName,
    XFile? newReferencePhoto,
    Set<TimeSlot>? newTimeSlots,
    MealTiming? newMealTiming,
    DateTime? newReceivedDate,
  }) async {
    final item = items.firstWhere((e) => e.id == id);
    if (newName != null && newName.trim().isNotEmpty) {
      item.name = newName.trim();
    }
    if (newReferencePhoto != null) {
      item.referencePhotoPath =
          await _store.savePhoto(newReferencePhoto, prefix: 'ref_$id');
    }
    if (newTimeSlots != null) {
      item.timeSlots = newTimeSlots;
    }
    item.mealTiming = newMealTiming;
    item.receivedDate = newReceivedDate;
    notifyListeners();
    await _store.save(items);
  }

  Future<void> removeItem(String id) async {
    items.removeWhere((e) => e.id == id);
    notifyListeners();
    await _store.save(items);
  }

  /// Marks [id] done for today's [slot] (or the "any" slot when the
  /// medication has no time-of-day assigned). Pass [proofPhoto] when the
  /// user chose to confirm by taking a photo instead of just tapping the
  /// check button.
  Future<void> completeToday(String id, {TimeSlot? slot, XFile? proofPhoto}) async {
    final item = items.firstWhere((e) => e.id == id);
    String? proofPath;
    if (proofPhoto != null) {
      proofPath = await _store.savePhoto(proofPhoto, prefix: 'proof_$id');
    }
    final today = item.completions.putIfAbsent(todayKey(), () => {});
    today[_slotKey(slot)] = MedicationCompletion(
      method: proofPhoto != null ? CompletionMethod.photo : CompletionMethod.tap,
      proofPhotoPath: proofPath,
    );
    notifyListeners();
    await _store.save(items);
  }

  /// Undoes an accidental tap/photo confirmation for today's [slot].
  Future<void> uncompleteToday(String id, {TimeSlot? slot}) async {
    final item = items.firstWhere((e) => e.id == id);
    item.completions[todayKey()]?.remove(_slotKey(slot));
    notifyListeners();
    await _store.save(items);
  }
}
