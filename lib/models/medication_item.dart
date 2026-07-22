import 'alarm_style.dart';
import 'meal_timing.dart';
import 'time_slot.dart';

/// Slot key used for medications that don't have a specific time-of-day
/// assigned — they behave like a single once-daily check.
const String anySlotKey = 'any';

enum CompletionMethod { tap, photo }

class MedicationCompletion {
  final CompletionMethod method;
  final String? proofPhotoPath;

  const MedicationCompletion({required this.method, this.proofPhotoPath});

  Map<String, dynamic> toJson() => {
        'method': method.name,
        'proofPhotoPath': proofPhotoPath,
      };

  factory MedicationCompletion.fromJson(Map<String, dynamic> json) {
    return MedicationCompletion(
      method: CompletionMethod.values.firstWhere(
        (m) => m.name == json['method'],
        orElse: () => CompletionMethod.tap,
      ),
      proofPhotoPath: json['proofPhotoPath'] as String?,
    );
  }
}

class MedicationItem {
  final String id;
  String name;
  String? referencePhotoPath;
  Set<TimeSlot> timeSlots;
  MealTiming? mealTiming;

  /// When this medication was added — used so the adherence calendar
  /// doesn't mark days before the medication existed as "missed".
  final DateTime createdAt;

  /// The day the medication was picked up/received (e.g. from a pharmacy).
  /// Purely informational — set and edited by the user, unrelated to
  /// [createdAt] or the adherence calendar.
  DateTime? receivedDate;

  /// The day this medication's course begins — null for items created
  /// before this feature existed, in which case adherence/streak
  /// calculations fall back to [createdAt]. Distinct from [receivedDate]
  /// (when the medication was picked up) — this is when the user actually
  /// starts taking it.
  DateTime? courseStartDate;

  /// The day this medication's course is expected to end. Null means an
  /// indefinite/chronic medication with no end date, in which case
  /// achievement is measured as a rolling monthly rate instead of a
  /// whole-course percentage.
  DateTime? courseEndDate;

  /// Alarm time (minutes since midnight) per slot key ([TimeSlot.name] or
  /// [anySlotKey]) — a slot missing from this map simply has no alarm.
  Map<String, int> alarmTimes;

  /// How this medication's alarms notify — applies to all of its slots.
  AlarmStyle alarmStyle;

  /// Free-text note (e.g. dictated via voice input) — a single field that
  /// gets overwritten, not a dated log.
  String? memo;

  /// Keyed by yyyy-MM-dd (see date_key.dart), then by slot key
  /// (a [TimeSlot.name], or [anySlotKey] for medications with no specific
  /// time-of-day) so morning/lunch/evening doses can be checked off
  /// independently on the same day.
  Map<String, Map<String, MedicationCompletion>> completions;

  MedicationItem({
    required this.id,
    required this.name,
    this.referencePhotoPath,
    Set<TimeSlot>? timeSlots,
    this.mealTiming,
    DateTime? createdAt,
    this.receivedDate,
    this.courseStartDate,
    this.courseEndDate,
    Map<String, int>? alarmTimes,
    this.alarmStyle = AlarmStyle.gentleSound,
    this.memo,
    Map<String, Map<String, MedicationCompletion>>? completions,
  })  : timeSlots = timeSlots ?? {},
        createdAt = createdAt ?? DateTime.now(),
        alarmTimes = alarmTimes ?? {},
        completions = completions ?? {};

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'referencePhotoPath': referencePhotoPath,
        'timeSlots': timeSlots.map((s) => s.name).toList(),
        'mealTiming': mealTiming?.name,
        'createdAt': createdAt.toIso8601String(),
        'receivedDate': receivedDate?.toIso8601String(),
        'courseStartDate': courseStartDate?.toIso8601String(),
        'courseEndDate': courseEndDate?.toIso8601String(),
        'alarmTimes': alarmTimes,
        'alarmStyle': alarmStyle.name,
        'memo': memo,
        'completions': completions.map(
          (date, bySlot) => MapEntry(
            date,
            bySlot.map((slot, c) => MapEntry(slot, c.toJson())),
          ),
        ),
      };

  factory MedicationItem.fromJson(Map<String, dynamic> json) {
    final rawCompletions = (json['completions'] as Map<String, dynamic>?) ?? {};
    final completions = rawCompletions.map((date, value) {
      final dateValue = value as Map<String, dynamic>;
      // Legacy format (pre time-slots): the date mapped directly to a
      // single completion object, e.g. {"method": "tap", ...}. Migrate it
      // into the new nested shape under the "any" slot so existing data
      // isn't lost.
      if (dateValue.containsKey('method')) {
        return MapEntry(date, {
          anySlotKey: MedicationCompletion.fromJson(dateValue),
        });
      }
      return MapEntry(
        date,
        dateValue.map(
          (slot, c) => MapEntry(slot, MedicationCompletion.fromJson(c as Map<String, dynamic>)),
        ),
      );
    });

    final rawSlots = (json['timeSlots'] as List?) ?? const [];
    final timeSlots = rawSlots
        .map((s) => TimeSlot.values.firstWhere((t) => t.name == s, orElse: () => TimeSlot.morning))
        .toSet();

    // Legacy data (pre createdAt) has no way to know the true add date —
    // fall back to the earliest completion on record so the calendar
    // doesn't retroactively mark days before that as "missed"; with no
    // history at all, today is the safest guess.
    DateTime createdAt;
    final rawCreatedAt = json['createdAt'] as String?;
    if (rawCreatedAt != null) {
      createdAt = DateTime.parse(rawCreatedAt);
    } else if (completions.keys.isNotEmpty) {
      final earliestKey = (completions.keys.toList()..sort()).first;
      createdAt = DateTime.parse(earliestKey);
    } else {
      createdAt = DateTime.now();
    }

    final rawMealTiming = json['mealTiming'] as String?;
    final mealTiming = rawMealTiming == null
        ? null
        : MealTiming.values.firstWhere((m) => m.name == rawMealTiming, orElse: () => MealTiming.beforeMeal);

    final rawReceivedDate = json['receivedDate'] as String?;
    final rawCourseStartDate = json['courseStartDate'] as String?;
    final rawCourseEndDate = json['courseEndDate'] as String?;

    final rawAlarmTimes = (json['alarmTimes'] as Map<String, dynamic>?) ?? {};
    final alarmTimes = rawAlarmTimes.map((k, v) => MapEntry(k, v as int));

    final rawAlarmStyle = json['alarmStyle'] as String?;
    final alarmStyle = AlarmStyle.values.firstWhere(
      (s) => s.name == rawAlarmStyle,
      orElse: () => AlarmStyle.gentleSound,
    );

    return MedicationItem(
      id: json['id'] as String,
      name: json['name'] as String,
      referencePhotoPath: json['referencePhotoPath'] as String?,
      timeSlots: timeSlots,
      mealTiming: mealTiming,
      createdAt: createdAt,
      receivedDate: rawReceivedDate == null ? null : DateTime.parse(rawReceivedDate),
      courseStartDate: rawCourseStartDate == null ? null : DateTime.parse(rawCourseStartDate),
      courseEndDate: rawCourseEndDate == null ? null : DateTime.parse(rawCourseEndDate),
      alarmTimes: alarmTimes,
      alarmStyle: alarmStyle,
      memo: json['memo'] as String?,
      completions: completions,
    );
  }
}
