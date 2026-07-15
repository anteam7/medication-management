import 'dart:typed_data';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/alarm_style.dart';
import '../models/medication_item.dart';
import '../models/time_slot.dart';

/// Schedules/cancels the daily local-notification alarms defined by each
/// [MedicationItem.alarmTimes] entry. Prefers exact alarm scheduling (falls
/// back to inexact only if the user hasn't granted the exact-alarm
/// permission) so reminders actually fire at the chosen time.
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

    // Android 12+ treats exact alarms as a special, user-revocable
    // permission granted through a system Settings screen (not an in-app
    // dialog) — the user may grant it well after this call returns, so the
    // actual capability is re-checked fresh at every scheduling call rather
    // than cached from this one request.
    await androidPlugin?.requestExactAlarmsPermission();
  }

  /// Whether exact alarms can currently be scheduled. `canScheduleExactNotifications`
  /// concerns an Android 12+-only API — on older Android versions (or any
  /// other platform hiccup) the underlying platform channel call can throw
  /// rather than just returning false, and since this result gates every
  /// `zonedSchedule` call, an uncaught exception here would silently break
  /// *all* alarm scheduling. Always resolve to a safe `false` instead.
  Future<bool> _canScheduleExact() async {
    try {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await androidPlugin?.canScheduleExactNotifications() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Ground-truth snapshot of the notification system's actual state —
  /// whether notifications/exact-alarms are really permitted, and what is
  /// actually scheduled at the OS level right now. Used to tell apart "the
  /// alarm was never scheduled" from "it's scheduled but the OS won't
  /// deliver it" when a reported alarm doesn't fire. Each check is isolated
  /// so one failing (e.g. an API unsupported on this Android version)
  /// doesn't blank out the rest of the report.
  Future<String> diagnosticsReport() async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    String notificationsLine;
    try {
      final enabled = await androidPlugin?.areNotificationsEnabled();
      notificationsLine = enabled == true ? '허용됨' : '꺼짐';
    } catch (e) {
      notificationsLine = '확인 실패 ($e)';
    }

    final exactAllowed = await _canScheduleExact();

    String pendingSection;
    try {
      final pending = await _plugin.pendingNotificationRequests();
      final buffer = StringBuffer('${pending.length}개');
      for (final p in pending) {
        buffer.write('\n· ${p.body ?? p.title ?? p.id}');
      }
      if (pending.isEmpty) {
        buffer.write('\n(0개라면 예약 자체가 실패한 것입니다)');
      }
      pendingSection = buffer.toString();
    } catch (e) {
      pendingSection = '확인 실패 ($e)';
    }

    return '알림 권한: $notificationsLine\n'
        '정확한 알람 권한: ${exactAllowed ? "허용됨" : "꺼짐 (부정확 모드로 대체됨)"}\n'
        '현재 예약된 알람: $pendingSection';
  }

  /// Fires a notification immediately (not scheduled) — used to verify
  /// permissions/channels are actually working, independent of any alarm
  /// scheduling or timezone logic.
  Future<void> showTestNotification() async {
    await _plugin.show(
      _stableId('test', 'now'),
      '테스트 알림',
      '이 알림이 보이면 알림 권한과 설정은 정상입니다',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _gentleSoundChannelId,
          '복약 알람 (잔잔한 소리)',
          channelDescription: '잔잔한 소리와 진동으로 복약 시간을 알려줍니다',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  /// Schedules a one-shot alarm ~1 minute from now via the exact same
  /// `zonedSchedule`/exact-alarm code path real medication alarms use
  /// (just without the daily repeat), so a short wait can confirm whether
  /// *scheduled* delivery works at all on this device — as opposed to
  /// [showTestNotification], which only proves immediate notifications work.
  Future<DateTime> scheduleQuickTestAlarm() async {
    final target = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
    await _plugin.zonedSchedule(
      _stableId('quicktest', 'now'),
      '⏰ 1분 테스트 알람',
      '이 알림이 보이면 예약(스케줄링)도 정상 작동하는 것입니다',
      target,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _gentleSoundChannelId,
          '복약 알람 (잔잔한 소리)',
          channelDescription: '잔잔한 소리와 진동으로 복약 시간을 알려줍니다',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          sound: const RawResourceAndroidNotificationSound('gentle_alarm'),
          enableVibration: true,
          vibrationPattern: _vibrationPattern,
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: await _canScheduleExact()
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
    return target;
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
      androidScheduleMode: await _canScheduleExact()
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
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
