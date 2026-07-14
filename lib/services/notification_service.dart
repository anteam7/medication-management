import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/alarm_style.dart';
import '../models/medication_item.dart';
import '../models/time_slot.dart';

/// Schedules/cancels the daily local-notification alarms defined by each
/// [MedicationItem.alarmTimes] entry. Uses `inexactAllowWhileIdle` scheduling
/// so no special "exact alarm" permission is required on Android 12+.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  static final Int64List _vibrationPattern =
      Int64List.fromList([0, 300, 200, 300, 200, 300]);

  static List<String> _allSlotKeys() => [
        ...TimeSlot.values.map((s) => s.name),
        anySlotKey,
      ];

  /// Android notification channels: sound/vibration are fixed the first
  /// time a channel is created, so each [AlarmStyle] needs its own channel
  /// rather than varying those fields per-notification.
  static const _vibrationChannelId = 'medication_alarm_vibration';
  static const _gentleSoundChannelId = 'medication_alarm_gentle';

  Future<void> init() async {
    tzdata.initializeTimeZones();
    // This app is Korean-only with no other locale support anywhere in its
    // UI, so the device's IANA timezone is assumed rather than detected via
    // an extra plugin.
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.createNotificationChannel(AndroidNotificationChannel(
      _vibrationChannelId,
      '복약 알람 (진동)',
      description: '진동으로 복약 시간을 알려줍니다',
      importance: Importance.high,
      playSound: false,
      enableVibration: true,
      vibrationPattern: _vibrationPattern,
    ));
    await androidPlugin?.createNotificationChannel(AndroidNotificationChannel(
      _gentleSoundChannelId,
      '복약 알람 (잔잔한 소리)',
      description: '잔잔한 소리와 진동으로 복약 시간을 알려줍니다',
      importance: Importance.high,
      playSound: true,
      sound: const RawResourceAndroidNotificationSound('gentle_alarm'),
      enableVibration: true,
      vibrationPattern: _vibrationPattern,
    ));

    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  /// Cancels every alarm this item could have, then reschedules only the
  /// slots currently present in [MedicationItem.alarmTimes] — a simple,
  /// always-correct sync with no need to diff against previous state.
  Future<void> syncForItem(MedicationItem item) async {
    await cancelAllForItem(item);
    for (final entry in item.alarmTimes.entries) {
      await _scheduleOne(item, entry.key, entry.value);
    }
  }

  Future<void> cancelAllForItem(MedicationItem item) async {
    for (final slotKey in _allSlotKeys()) {
      await _plugin.cancel(_stableId(item.id, slotKey));
    }
  }

  Future<void> _scheduleOne(MedicationItem item, String slotKey, int minutes) async {
    final label = slotKey == anySlotKey
        ? null
        : TimeSlot.values.firstWhere((s) => s.name == slotKey).label;
    final body = label == null
        ? '${item.name} 복용할 시간입니다'
        : '$label · ${item.name} 복용할 시간입니다';

    final isGentleSound = item.alarmStyle == AlarmStyle.gentleSound;
    final androidDetails = isGentleSound
        ? AndroidNotificationDetails(
            _gentleSoundChannelId,
            '복약 알람 (잔잔한 소리)',
            channelDescription: '잔잔한 소리와 진동으로 복약 시간을 알려줍니다',
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('gentle_alarm'),
            enableVibration: true,
            vibrationPattern: _vibrationPattern,
          )
        : AndroidNotificationDetails(
            _vibrationChannelId,
            '복약 알람 (진동)',
            channelDescription: '진동으로 복약 시간을 알려줍니다',
            importance: Importance.high,
            priority: Priority.high,
            playSound: false,
            enableVibration: true,
            vibrationPattern: _vibrationPattern,
          );

    await _plugin.zonedSchedule(
      _stableId(item.id, slotKey),
      '약 먹을 시간이에요',
      body,
      _nextInstanceOf(minutes),
      NotificationDetails(android: androidDetails, iOS: const DarwinNotificationDetails()),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  tz.TZDateTime _nextInstanceOf(int minutesSinceMidnight) {
    final now = tz.TZDateTime.now(tz.local);
    final hour = minutesSinceMidnight ~/ 60;
    final minute = minutesSinceMidnight % 60;
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Deterministic djb2-style string hash — used instead of Dart's built-in
  /// [String.hashCode], which has no cross-version stability guarantee.
  /// Notification IDs must stay stable across app restarts so a later
  /// cancel/reschedule can find the exact same alarm.
  int _stableId(String itemId, String slotKey) {
    final key = '${itemId}_$slotKey';
    int hash = 5381;
    for (final unit in key.codeUnits) {
      hash = ((hash << 5) + hash + unit) & 0x7fffffff;
    }
    return hash;
  }
}
