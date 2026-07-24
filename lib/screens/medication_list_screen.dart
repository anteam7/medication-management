import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/alarm_style.dart';
import '../models/app_theme.dart';
import '../models/app_theme_state.dart';
import '../models/meal_timing.dart';
import '../models/medication_item.dart';
import '../models/medication_state.dart';
import '../models/time_slot.dart';
import '../services/adherence.dart';
import '../services/notification_service.dart';
import '../utils/date_key.dart';
import '../widgets/simple_time_picker.dart';
import '../widgets/theme_picker_sheet.dart';
import 'achievement_screen.dart';
import 'add_medication_sheet.dart';
import 'calendar_screen.dart';
import 'photo_match_screen.dart';

typedef _AddResult = ({
  String name,
  XFile? photo,
  Set<TimeSlot> timeSlots,
  MealTiming? mealTiming,
  DateTime? receivedDate,
  DateTime? courseStartDate,
  DateTime? courseEndDate,
  Map<String, int> alarmTimes,
  AlarmStyle alarmStyle,
  String? memo,
});

enum _MenuAction { alarmDiagnostics, quickTestAlarm }

/// Fixed per-slot identity (icon + color), independent of the active theme —
/// like the calendar's green/red status colors — so 아침/점심/저녁 are
/// recognizable at a glance no matter which theme is selected.
(IconData, Color) _slotIdentity(TimeSlot? slot) => switch (slot) {
      TimeSlot.morning => (Icons.wb_twilight, const Color(0xFFE08A3C)),
      TimeSlot.lunch => (Icons.wb_sunny_outlined, const Color(0xFFD9A514)),
      TimeSlot.evening => (Icons.nightlight_outlined, const Color(0xFF7B6FD0)),
      null => (Icons.schedule_outlined, const Color(0xFF8A9296)),
    };

class MedicationListScreen extends StatelessWidget {
  const MedicationListScreen({super.key});

  Future<void> _openAddSheet(
    BuildContext context, {
    MedicationItem? existing,
  }) async {
    final result = await showModalBottomSheet<_AddResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddMedicationSheet(existing: existing),
    );
    if (result == null || !context.mounted) return;

    final state = context.read<MedicationState>();
    if (existing == null) {
      await state.addItem(
        name: result.name,
        referencePhoto: result.photo,
        timeSlots: result.timeSlots,
        mealTiming: result.mealTiming,
        receivedDate: result.receivedDate,
        courseStartDate: result.courseStartDate,
        courseEndDate: result.courseEndDate,
        alarmTimes: result.alarmTimes,
        alarmStyle: result.alarmStyle,
        memo: result.memo,
      );
    } else {
      await state.editItem(
        existing.id,
        newName: result.name,
        newReferencePhoto: result.photo,
        newTimeSlots: result.timeSlots,
        newMealTiming: result.mealTiming,
        newReceivedDate: result.receivedDate,
        newCourseStartDate: result.courseStartDate,
        newCourseEndDate: result.courseEndDate,
        newAlarmTimes: result.alarmTimes,
        newAlarmStyle: result.alarmStyle,
        newMemo: result.memo,
      );
    }
  }

  /// Sends an immediate test notification (so the user can watch for it)
  /// and shows what's actually scheduled at the OS level, in one dialog —
  /// this tells apart "the alarm never got scheduled" from "it's scheduled
  /// but the OS/manufacturer battery settings are blocking delivery".
  Future<void> _showAlarmDiagnostics(BuildContext context) async {
    String? testError;
    try {
      await NotificationService.instance.showTestNotification();
    } catch (e) {
      testError = e.toString();
    }

    String report;
    try {
      report = await NotificationService.instance.diagnosticsReport();
    } catch (e) {
      // Belt-and-suspenders: even if a diagnostic check itself misbehaves,
      // the user should see *something* rather than the button silently
      // doing nothing.
      report = '진단 정보를 가져오는 중 오류가 발생했습니다: $e';
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('알람 진단'),
        content: SingleChildScrollView(
          child: Text(
            testError == null
                ? '테스트 알림을 보냈습니다. 알림창에서 바로 확인하세요.\n\n$report'
                : '테스트 알림 전송 실패: $testError\n\n$report',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
        ],
      ),
    );
  }

  /// Schedules a real one-shot exact alarm ~1 minute out, using the exact
  /// same delivery mechanism as daily medication alarms. Lets the user get
  /// an answer in ~1 minute on whether *scheduled* delivery works at all on
  /// this device, instead of waiting for the next real medication time —
  /// isolating "exact-alarm delivery is broken/blocked" from "something
  /// specific to the daily-repeat scheduling path".
  Future<void> _runQuickTestAlarm(BuildContext context) async {
    String message;
    try {
      final target = await NotificationService.instance.scheduleQuickTestAlarm();
      final hh = target.hour.toString().padLeft(2, '0');
      final mm = target.minute.toString().padLeft(2, '0');
      final ss = target.second.toString().padLeft(2, '0');
      message = '$hh:$mm:$ss 에 알람이 울리도록 예약했습니다.\n'
          '그 시간에 화면을 보지 않아도 알림이 오는지 확인해주세요.';
    } catch (e) {
      message = '예약 실패: $e';
    }

    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('1분 테스트 알람'),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인')),
        ],
      ),
    );
  }

  /// Opens the camera, absorbing the PlatformException thrown when camera
  /// access is denied/unavailable — the user gets a snackbar instead of a
  /// silently unresponsive button.
  Future<XFile?> _pickCameraPhoto(BuildContext context) async {
    try {
      return await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('카메라를 열 수 없어요. 카메라 권한을 확인해주세요')),
        );
      }
      return null;
    }
  }

  Future<void> _confirmWithPhoto(
    BuildContext context,
    MedicationItem item,
    TimeSlot? slot,
  ) async {
    final photo = await _pickCameraPhoto(context);
    if (photo == null || !context.mounted) return;

    // The reference photo is guaranteed to exist here — this action only
    // shows as "인증사진" (as opposed to "사진 등록") once one is set.
    final confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PhotoMatchScreen(
          referencePhotoPath: item.referencePhotoPath!,
          capturedPhoto: photo,
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await context.read<MedicationState>().completeToday(
      item.id,
      slot: slot,
      proofPhoto: photo,
    );
  }

  /// Registers a reference photo for an item that doesn't have one yet —
  /// the list tile's "사진" action means this until a reference photo
  /// exists, then switches to [_confirmWithPhoto] (완료 인증사진) instead,
  /// since the same camera icon previously always did the latter even for
  /// items with no photo at all, silently accomplishing nothing the user
  /// could see.
  Future<void> _registerReferencePhoto(BuildContext context, MedicationItem item) async {
    final photo = await _pickCameraPhoto(context);
    if (photo == null || !context.mounted) return;
    await context.read<MedicationState>().setReferencePhoto(item.id, photo);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('약 사진이 등록되었습니다')));
  }

  Future<void> _handleDelete(BuildContext context, MedicationItem item) async {
    final confirmed = await _confirmDelete(context, item);
    if (confirmed && context.mounted) {
      await context.read<MedicationState>().removeItem(item.id);
    }
  }

  /// Asks the user to confirm before deleting [item] entirely (including
  /// its other time-slot sections, reference photo and full completion
  /// history) — a pure yes/no decision with no side effects. Callers are
  /// responsible for actually removing the item afterwards; in particular,
  /// [Dismissible.confirmDismiss] must stay side-effect-free and let
  /// [Dismissible.onDismissed] do the removal once its swipe animation
  /// finishes, or the widget can be torn down mid-animation and the item
  /// never actually gets removed from view.
  Future<bool> _confirmDelete(BuildContext context, MedicationItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('약 삭제'),
        content: Text("'${item.name}' 약을 삭제하시겠습니까?\n등록된 사진과 복용 기록도 함께 삭제됩니다."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('삭제',
                style: TextStyle(color: Theme.of(ctx).colorScheme.error)),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// Items belonging to [slot] (or items with no time-of-day assigned, when
  /// [slot] is null) — a medication assigned to multiple slots shows up in
  /// each of its sections, checked off independently.
  List<MedicationItem> _itemsForSlot(
    List<MedicationItem> items,
    TimeSlot? slot,
  ) {
    return items.where((item) {
      return slot == null
          ? item.timeSlots.isEmpty
          : item.timeSlots.contains(slot);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MedicationState>();
    final themeName = context.watch<AppThemeState>().current;

    // Drives the in-app red dot below instead of relying on the OS launcher
    // badge, which — unlike this — is recalculated fresh from state every
    // build and can't get stuck showing a stale count.
    final hasIncompleteToday =
        state.items.isNotEmpty && !state.items.every(state.isFullyCompletedToday);

    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          '약콕',
          style: TextStyle(fontFamily: 'Jua', fontSize: 28),
        ),
        actions: [
          IconButton(
            tooltip: '기간별 복약 성취',
            icon: const Icon(Icons.emoji_events_outlined),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const AchievementScreen())),
          ),
          IconButton(
            tooltip: hasIncompleteToday ? '복약 달력 (오늘 미완료 있음)' : '복약 달력',
            icon: Badge(
              isLabelVisible: hasIncompleteToday,
              smallSize: 8,
              backgroundColor: Colors.redAccent,
              child: const Icon(Icons.calendar_month_outlined),
            ),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CalendarScreen())),
          ),
          IconButton(
            tooltip: '테마',
            icon: const Icon(Icons.palette_outlined),
            onPressed: () => showThemePickerSheet(context),
          ),
          PopupMenuButton<_MenuAction>(
            tooltip: '더보기',
            onSelected: (action) async {
              switch (action) {
                case _MenuAction.alarmDiagnostics:
                  await _showAlarmDiagnostics(context);
                case _MenuAction.quickTestAlarm:
                  await _runQuickTestAlarm(context);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _MenuAction.alarmDiagnostics,
                child: ListTile(
                  leading: Icon(Icons.bug_report_outlined),
                  title: Text('알람 진단'),
                ),
              ),
              PopupMenuItem(
                value: _MenuAction.quickTestAlarm,
                child: ListTile(
                  leading: Icon(Icons.timer_outlined),
                  title: Text('1분 테스트 알람'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: appBackgroundGradient(themeName, Theme.of(context).brightness),
        ),
        child: !state.isLoaded
            ? const Center(child: CircularProgressIndicator())
            : state.items.isEmpty
            ? _EmptyState(onAdd: () => _openAddSheet(context))
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                children: [
                  _TodayHeroCard(state: state),
                  const SizedBox(height: 16),
                  _AchievementSummaryStrip(items: state.items),
                  for (final slot in [
                    TimeSlot.morning,
                    TimeSlot.lunch,
                    TimeSlot.evening,
                    null,
                  ])
                    ..._buildSection(context, state, slot),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('약 추가'),
      ),
    );
  }

  List<Widget> _buildSection(
    BuildContext context,
    MedicationState state,
    TimeSlot? slot,
  ) {
    final items = _itemsForSlot(state.items, slot);
    if (items.isEmpty) return const [];
    final (icon, color) = _slotIdentity(slot);

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 8),
            Text(
              slot?.label ?? '시간 미지정',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(width: 6),
            Text('${items.length}', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
      for (final item in items) ...[
        Dismissible(
          key: ValueKey('${item.id}_${slot?.name ?? 'any'}'),
          direction: DismissDirection.endToStart,
          background: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.error,
              borderRadius: BorderRadius.circular(18),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete_outline, color: Colors.white),
          ),
          confirmDismiss: (_) => _confirmDelete(context, item),
          onDismissed: (_) =>
              context.read<MedicationState>().removeItem(item.id),
          child: _MedicationTile(
            item: item,
            done: state.isCompletedForSlot(item, slot),
            alarmMinutes: item.alarmTimes[slot?.name ?? anySlotKey],
            onTapCheck: () {
              final s = context.read<MedicationState>();
              state.isCompletedForSlot(item, slot)
                  ? s.uncompleteToday(item.id, slot: slot)
                  : s.completeToday(item.id, slot: slot);
            },
            onPhotoCheck: () => item.referencePhotoPath == null
                ? _registerReferencePhoto(context, item)
                : _confirmWithPhoto(context, item, slot),
            onEdit: () => _openAddSheet(context, existing: item),
            onDelete: () => _handleDelete(context, item),
          ),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }
}

/// The screen's signature element: today's date, a context-aware greeting
/// and a progress ring summarizing how much of today's medication is done —
/// the one glance that answers "am I on track today?".
class _TodayHeroCard extends StatelessWidget {
  final MedicationState state;
  const _TodayHeroCard({required this.state});

  static const _weekdays = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];

  String _greeting(int hour, bool allDone) {
    if (allDone) return '오늘 복약을 모두 마쳤어요!';
    if (hour < 5) return '늦은 밤이에요, 푹 쉬세요';
    if (hour < 11) return '좋은 아침이에요';
    if (hour < 14) return '점심 약 잊지 않으셨죠?';
    if (hour < 18) return '오늘도 잘 챙기고 있어요';
    return '저녁 약까지 마무리해요';
  }

  @override
  Widget build(BuildContext context) {
    int done = 0, total = 0;
    for (final item in state.items) {
      final slots = item.timeSlots.isEmpty
          ? <TimeSlot?>[null]
          : item.timeSlots.map<TimeSlot?>((s) => s).toList();
      for (final slot in slots) {
        total++;
        if (state.isCompletedForSlot(item, slot)) done++;
      }
    }
    final progress = total == 0 ? 0.0 : done / total;
    final allDone = total > 0 && done == total;

    final scheme = Theme.of(context).colorScheme;
    final onAccent = scheme.onPrimary;
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 18, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, Colors.black, 0.22)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${now.month}월 ${now.day}일 ${_weekdays[now.weekday - 1]}',
                  style: TextStyle(
                    color: onAccent.withValues(alpha: 0.75),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _greeting(now.hour, allDone),
                  style: TextStyle(
                    color: onAccent,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '오늘 복약 $done / $total',
                  style: TextStyle(
                    color: onAccent.withValues(alpha: 0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 64,
                  height: 64,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    color: onAccent,
                    backgroundColor: onAccent.withValues(alpha: 0.25),
                  ),
                ),
                allDone
                    ? Icon(Icons.check_rounded, color: onAccent, size: 28)
                    : Text(
                        '${(progress * 100).round()}%',
                        style: TextStyle(
                          color: onAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A compact, always-on-screen aggregate — achievement shouldn't be hidden
/// behind the trophy icon, it should be one of the first things visible when
/// the app opens. Tapping opens [AchievementScreen] for the full view.
///
/// This is a single combined "전체 기간" reading across every medication with
/// a defined course period, not a per-medication list — no individual
/// medication name is shown, since the number is a total. There's no "오늘"
/// reading here since that's already covered by the today hero card above.
/// Indefinite/chronic medications are represented in that hero card too.
class _AchievementSummaryStrip extends StatelessWidget {
  final List<MedicationItem> items;
  const _AchievementSummaryStrip({required this.items});

  void _openFull(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AchievementScreen()),
      );

  @override
  Widget build(BuildContext context) {
    final courseItems = items.where((i) => i.courseEndDate != null).toList();
    if (courseItems.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => _openFull(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.emoji_events_outlined,
                      size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 6),
                  Text('기간별 복약 성취', style: theme.textTheme.titleSmall),
                  const Spacer(),
                  Text('전체보기', style: theme.textTheme.bodySmall),
                  Icon(Icons.chevron_right,
                      size: 16, color: theme.colorScheme.onSurfaceVariant),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _openFull(context),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: _MiniBarRow(label: '전체 기간', rate: aggregateCourseRateFor(courseItems)),
            ),
          ),
        ],
      ),
    );
  }
}

/// A progress bar on the left with its label + percentage grouped into a
/// same-size block on the right, so the percentage lines up identically
/// regardless of value ("45%" vs "100%" no longer changes the bar's width,
/// since the block next to it is now a fixed size).
class _MiniBarRow extends StatelessWidget {
  final String label;
  final double? rate;
  const _MiniBarRow({required this.label, required this.rate});

  // Sized for the longest realistic single line ("전체 기간 100%") at these
  // font sizes, now that label + percentage sit side by side instead of
  // stacked across two lines.
  static const _blockWidth = 104.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rate = this.rate;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: rate ?? 0,
              minHeight: 12,
              color: scheme.primary,
              backgroundColor: scheme.primary.withValues(alpha: 0.15),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          width: _blockWidth,
          padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                rate == null ? '-' : '${(rate * 100).round()}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    scheme.primary.withValues(alpha: 0.85),
                    Color.lerp(scheme.primary, Colors.black, 0.2)!,
                  ],
                ),
              ),
              child: Icon(Icons.medication_outlined,
                  size: 44, color: scheme.onPrimary),
            ),
            const SizedBox(height: 20),
            Text('아직 등록된 약이 없어요',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              '약을 추가하면 시간대별 체크와 알람,\n복용 달력 기록이 시작돼요',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('약 추가'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicationTile extends StatelessWidget {
  final MedicationItem item;
  final bool done;
  final int? alarmMinutes;
  final VoidCallback onTapCheck;
  final VoidCallback onPhotoCheck;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MedicationTile({
    required this.item,
    required this.done,
    required this.alarmMinutes,
    required this.onTapCheck,
    required this.onPhotoCheck,
    required this.onEdit,
    required this.onDelete,
  });

  void _showMemoDialog(BuildContext context, MedicationItem item) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${item.name} 메모'),
        content: Text(item.memo ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      // Margin zero so the swipe-to-delete background drawn by Dismissible
      // lines up exactly with the card's rounded edges; spacing between
      // tiles is handled by the list instead.
      margin: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Row(
              children: [
                _buildPhoto(context),
                const SizedBox(width: 12),
                Expanded(child: _buildInfo(context)),
                const SizedBox(width: 10),
                _CheckButton(done: done, onTap: onTapCheck),
              ],
            ),
          ),
          const Divider(height: 1),
          _buildActionRow(context),
        ],
      ),
    );
  }

  Widget _buildPhoto(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final placeholder = Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.medication_outlined, color: scheme.primary, size: 26),
    );

    final path = item.referencePhotoPath;
    if (path == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.file(
        File(path),
        width: 54,
        height: 54,
        fit: BoxFit.cover,
        // The stored path can go stale (file cleaned up or restored from a
        // backup without its photos) — fall back to the icon placeholder
        // instead of a render error.
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }

  Widget _buildInfo(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                item.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done ? scheme.onSurfaceVariant : scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                dDayLabel(item.receivedDate ?? item.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            if (item.mealTiming != null)
              _MetaChip(
                icon: Icons.restaurant_outlined,
                label: item.mealTiming!.label,
              ),
            if (alarmMinutes != null)
              _MetaChip(
                icon: Icons.notifications_none_rounded,
                label: formatMinutes(alarmMinutes!),
              ),
            if (item.receivedDate != null)
              _MetaChip(
                icon: Icons.event_available_outlined,
                label: '받은날 ${dateKey(item.receivedDate!)}',
              ),
            // No defined course end date means no "whole" to show a
            // percentage against — a running lifetime count instead.
            if (item.courseEndDate == null)
              _MetaChip(
                icon: Icons.checklist_rtl_outlined,
                label: '시작일부터 총 ${totalTakenCountFor(item)}회 복용',
              ),
            if (item.memo != null && item.memo!.trim().isNotEmpty)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _showMemoDialog(context, item),
                child: const _MetaChip(
                  icon: Icons.sticky_note_2_outlined,
                  label: '메모',
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionRow(BuildContext context) {
    final hasReferencePhoto = item.referencePhotoPath != null;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionButton(
          icon: hasReferencePhoto
              ? Icons.camera_alt_outlined
              : Icons.add_a_photo_outlined,
          label: hasReferencePhoto ? '인증사진' : '사진 등록',
          onTap: onPhotoCheck,
        ),
        _ActionButton(icon: Icons.edit_outlined, label: '수정', onTap: onEdit),
        _ActionButton(
          icon: Icons.delete_outline,
          label: '삭제',
          color: Theme.of(context).colorScheme.error,
          onTap: onDelete,
        ),
      ],
    );
  }
}

/// The one action taken every day, made satisfying: a large circular toggle
/// that fills with the theme's accent when today's dose is checked off.
class _CheckButton extends StatelessWidget {
  final bool done;
  final VoidCallback onTap;
  const _CheckButton({required this.done, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: done ? '오늘 복용 완료됨, 누르면 취소' : '오늘 복용 체크',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? scheme.primary : Colors.transparent,
            border: done
                ? null
                : Border.all(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                    width: 1.6,
                  ),
          ),
          child: Icon(
            Icons.check_rounded,
            size: 24,
            color: done
                ? scheme.onPrimary
                : scheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}

/// Small icon+label badge for a tile's secondary facts (식전/식후, alarm
/// time, received date, memo) — quieter than dot-joined text and scannable.
class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
