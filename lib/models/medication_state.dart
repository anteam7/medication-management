import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/medication_store.dart';
import '../services/notification_service.dart';
import '../utils/date_key.dart';
import 'alarm_style.dart';
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

    // Re-sync every alarm on each app start: this is what actually applies
    // an exact-alarm permission the user granted after items were first
    // created (existing alarms are otherwise never rescheduled), and it's a
    // cheap, idempotent safety net against any other scheduling hiccup.
    for (final item in items) {
      try {
        await NotificationService.instance.syncForItem(item);
      } catch (_) {}
    }
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
    Map<String, int> alarmTimes = const {},
    AlarmStyle alarmStyle = AlarmStyle.gentleSound,
    String? memo,
  }) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    String? photoPath;
    if (referencePhoto != null) {
      photoPath = await _store.savePhoto(referencePhoto, prefix: 'ref_$id');
    }

    final item = MedicationItem(
      id: id,
      name: trimmed,
      referencePhotoPath: photoPath,
      timeSlots: timeSlots,
      mealTiming: mealTiming,
      receivedDate: receivedDate,
      alarmTimes: alarmTimes,
      alarmStyle: alarmStyle,
      memo: memo,
    );
    items.add(item);
    notifyListeners();
    await _store.save(items);
    await NotificationService.instance.syncForItem(item);
  }

  Future<void> editItem(
    String id, {
    String? newName,
    XFile? newReferencePhoto,
    Set<TimeSlot>? newTimeSlots,
    MealTiming? newMealTiming,
    DateTime? newReceivedDate,
    Map<String, int> newAlarmTimes = const {},
    AlarmStyle newAlarmStyle = AlarmStyle.gentleSound,
    String? newMemo,
  }) async {
    final item = items.firstWhere((e) => e.id == id);
    if (newName != null && newName.trim().isNotEmpty) {
      item.name = newName.trim();
    }
    if (newReferencePhoto != null) {
      final oldPhotoPath = item.referencePhotoPath;
      item.referencePhotoPath =
          await _store.savePhoto(newReferencePhoto, prefix: 'ref_$id');
      await _store.deletePhoto(oldPhotoPath);
    }
    if (newTimeSlots != null) {
      item.timeSlots = newTimeSlots;
    }
    item.mealTiming = newMealTiming;
    item.receivedDate = newReceivedDate;
    item.alarmTimes = newAlarmTimes;
    item.alarmStyle = newAlarmStyle;
    item.memo = newMemo;
    notifyListeners();
    await _store.save(items);
    await NotificationService.instance.syncForItem(item);
  }

  /// Registers/replaces just the reference photo for [id] — used by the
  /// list screen's quick "사진 등록" action for items that don't have one
  /// yet, without going through the full edit sheet.
  Future<void> setReferencePhoto(String id, XFile photo) async {
    final item = items.firstWhere((e) => e.id == id);
    final oldPhotoPath = item.referencePhotoPath;
    item.referencePhotoPath = await _store.savePhoto(photo, prefix: 'ref_$id');
    notifyListeners();
    await _store.save(items);
    await _store.deletePhoto(oldPhotoPath);
  }

  Future<void> removeItem(String id) async {
    final index = items.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final item = items[index];

    // Remove first and treat alarm cleanup as best-effort: a plugin/platform
    // hiccup cancelling a scheduled notification must never prevent the
    // medication itself from actually being deleted.
    items.removeAt(index);
    notifyListeners();
    await _store.save(items);
    try {
      await NotificationService.instance.cancelAllForItem(item);
    } catch (_) {}

    // The item is already gone from the list and storage — now clean up its
    // photo files (reference + every completion's proof shot) so deleting a
    // medication doesn't strand its images in permanent storage forever.
    await _store.deletePhoto(item.referencePhotoPath);
    for (final bySlot in item.completions.values) {
      for (final completion in bySlot.values) {
        await _store.deletePhoto(completion.proofPhotoPath);
      }
    }
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
    final previous = today[_slotKey(slot)];
    today[_slotKey(slot)] = MedicationCompletion(
      method: proofPhoto != null ? CompletionMethod.photo : CompletionMethod.tap,
      proofPhotoPath: proofPath,
    );
    notifyListeners();
    await _store.save(items);
    // Re-confirming a slot that already had a photo proof replaces the map
    // entry — delete the now-unreferenced old proof file as well.
    await _store.deletePhoto(previous?.proofPhotoPath);
  }

  /// Undoes an accidental tap/photo confirmation for today's [slot].
  Future<void> uncompleteToday(String id, {TimeSlot? slot}) async {
    final item = items.firstWhere((e) => e.id == id);
    final removed = item.completions[todayKey()]?.remove(_slotKey(slot));
    notifyListeners();
    await _store.save(items);
    // The undone completion's proof shot (if any) is no longer referenced
    // by anything — delete the file too.
    await _store.deletePhoto(removed?.proofPhotoPath);
  }
}
