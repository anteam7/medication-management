import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/alarm_style.dart';
import '../models/meal_timing.dart';
import '../models/medication_item.dart';
import '../models/medication_state.dart';
import '../models/time_slot.dart';
import '../services/notification_service.dart';
import '../utils/date_key.dart';
import '../widgets/simple_time_picker.dart';
import '../widgets/theme_picker_sheet.dart';
import 'add_medication_sheet.dart';
import 'calendar_screen.dart';

typedef _AddResult = ({
  String name,
  XFile? photo,
  Set<TimeSlot> timeSlots,
  MealTiming? mealTiming,
  DateTime? receivedDate,
  Map<String, int> alarmTimes,
  AlarmStyle alarmStyle,
  String? memo,
});

enum _MenuAction { alarmDiagnostics, quickTestAlarm, theme, calendar }

class MedicationListScreen extends StatelessWidget {
  const MedicationListScreen({super.key});

  Future<void> _openAddSheet(
    BuildContext context, {
    MedicationItem? existing,
  }) async {
    final result = await showModalBottomSheet<_AddResult>(
      context: context,
      isScrollControlled: true,
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

  Future<void> _confirmWithPhoto(
    BuildContext context,
    MedicationItem item,
    TimeSlot? slot,
  ) async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (photo == null || !context.mounted) return;
    await context.read<MedicationState>().completeToday(
      item.id,
      slot: slot,
      proofPhoto: photo,
    );
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
            child: const Text('삭제', style: TextStyle(color: Colors.redAccent)),
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('복약 관리'),
        actions: [
          PopupMenuButton<_MenuAction>(
            tooltip: '더보기',
            onSelected: (action) async {
              switch (action) {
                case _MenuAction.alarmDiagnostics:
                  await _showAlarmDiagnostics(context);
                case _MenuAction.quickTestAlarm:
                  await _runQuickTestAlarm(context);
                case _MenuAction.theme:
                  showThemePickerSheet(context);
                case _MenuAction.calendar:
                  Navigator.of(
                    context,
                  ).push(MaterialPageRoute(builder: (_) => const CalendarScreen()));
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
              PopupMenuItem(
                value: _MenuAction.theme,
                child: ListTile(
                  leading: Icon(Icons.palette_outlined),
                  title: Text('테마'),
                ),
              ),
              PopupMenuItem(
                value: _MenuAction.calendar,
                child: ListTile(
                  leading: Icon(Icons.calendar_month),
                  title: Text('복약 달력'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: !state.isLoaded
          ? const Center(child: CircularProgressIndicator())
          : state.items.isEmpty
          ? _EmptyState(onAdd: () => _openAddSheet(context))
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                for (final slot in [
                  TimeSlot.morning,
                  TimeSlot.lunch,
                  TimeSlot.evening,
                  null,
                ])
                  ..._buildSection(context, state, slot),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddSheet(context),
        child: const Icon(Icons.add),
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

    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
        child: Text(
          slot?.label ?? '시간 미지정',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
      for (final item in items) ...[
        Dismissible(
          key: ValueKey('${item.id}_${slot?.name ?? 'any'}'),
          direction: DismissDirection.endToStart,
          background: Container(
            decoration: BoxDecoration(
              color: Colors.redAccent,
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Icon(Icons.delete, color: Colors.white),
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
            onPhotoCheck: () => _confirmWithPhoto(context, item, slot),
            onEdit: () => _openAddSheet(context, existing: item),
            onDelete: () => _handleDelete(context, item),
          ),
        ),
        const SizedBox(height: 8),
      ],
    ];
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.medication_outlined, size: 64, color: Colors.grey),
          const SizedBox(height: 12),
          const Text('등록된 약이 없습니다'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('약 추가'),
          ),
        ],
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
      child: Column(
        children: [
          _buildInfoTile(context),
          const Divider(height: 1),
          _buildActionRow(context),
        ],
      ),
    );
  }

  Widget _buildInfoTile(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 22,
        backgroundImage: item.referencePhotoPath != null
            ? FileImage(File(item.referencePhotoPath!))
            : null,
        child: item.referencePhotoPath == null
            ? const Icon(Icons.medication)
            : null,
      ),
      // Sits opposite the reference-photo avatar on the leading side, so
      // the one action taken every day is visually distinct from the
      // manage-this-item actions (사진/수정/삭제) in the row below.
      trailing: _ActionButton(
        icon: done ? Icons.check_circle : Icons.check_circle_outline,
        label: '수행 여부',
        color: done ? Colors.green : null,
        onTap: onTapCheck,
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              item.name,
              overflow: TextOverflow.ellipsis,
              style: done
                  ? const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              dDayLabel(item.receivedDate ?? item.createdAt),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          if (item.memo != null && item.memo!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: InkWell(
                onTap: () => _showMemoDialog(context, item),
                child: Icon(
                  Icons.sticky_note_2_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          Expanded(
            child: Text(
              [
                if (item.mealTiming != null) item.mealTiming!.label,
                done ? '오늘 완료 ✅' : '오늘 미완료',
                if (alarmMinutes != null) '🔔 ${formatMinutes(alarmMinutes!)}',
                if (item.receivedDate != null)
                  '받은날 ${dateKey(item.receivedDate!)}',
              ].join(' · '),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRow(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _ActionButton(
          icon: Icons.camera_alt_outlined,
          label: '사진',
          onTap: onPhotoCheck,
        ),
        _ActionButton(icon: Icons.edit_outlined, label: '수정', onTap: onEdit),
        _ActionButton(
          icon: Icons.delete_outline,
          label: '삭제',
          color: Colors.redAccent,
          onTap: onDelete,
        ),
      ],
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
        foregroundColor: color,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 12)),
    );
  }
}
