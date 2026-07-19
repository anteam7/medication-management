import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_theme.dart';
import '../models/app_theme_state.dart';
import '../models/medication_item.dart';
import '../models/medication_state.dart';
import '../models/time_slot.dart';
import '../services/adherence.dart';
import '../utils/date_key.dart';
import '../widgets/simple_time_picker.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _visibleMonth = DateTime(now.year, now.month);
      _selectedDay = dateOnly(now);
    });
  }

  void _selectDay(DateTime day) {
    setState(() => _selectedDay = day);
  }

  static const _slotOrder = [TimeSlot.morning, TimeSlot.lunch, TimeSlot.evening];

  /// e.g. "아침 08:00, 저녁 20:00" — slots in a fixed daily order, followed by
  /// the no-time-of-day alarm (if any) last.
  String _alarmSummary(MedicationItem item) {
    final parts = <String>[
      for (final slot in _slotOrder)
        if (item.alarmTimes[slot.name] case final minutes?)
          '${slot.label} ${formatMinutes(minutes)}',
      if (item.alarmTimes[anySlotKey] case final minutes?) formatMinutes(minutes),
    ];
    return parts.join(', ');
  }

  void _showAlarmSummary(BuildContext context, List<MedicationItem> items) {
    final withAlarms = items.where((item) => item.alarmTimes.isNotEmpty).toList();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('설정된 알림', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (withAlarms.isEmpty)
                const Text('설정된 알림이 없어요')
              else
                for (final item in withAlarms)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Icon(Icons.notifications_none_rounded,
                            size: 17,
                            color: Theme.of(ctx).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('${item.name}: ${_alarmSummary(item)}'),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = context.watch<MedicationState>().items;
    final themeName = context.watch<AppThemeState>().current;
    final theme = Theme.of(context);
    final year = _visibleMonth.year;
    final month = _visibleMonth.month;
    final firstOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // DateTime.weekday: Monday=1..Sunday=7 — we want a Sunday-first grid.
    final leadingBlanks = firstOfMonth.weekday % 7;
    final today = dateOnly(DateTime.now());

    final cells = <Widget>[
      for (int i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
      for (int day = 1; day <= daysInMonth; day++)
        Builder(builder: (context) {
          final date = DateTime(year, month, day);
          return _DayCell(
            date: date,
            status: dayStatusFor(date, items),
            pillFlags: dailyStatusFlags(date, items),
            isToday: date == today,
            selected: _selectedDay == date,
            onTap: () => _selectDay(date),
          );
        }),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('복약 달력'),
        actions: [
          IconButton(
            icon: const Icon(Icons.alarm),
            tooltip: '설정된 알림',
            onPressed: () => _showAlarmSummary(context, items),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: appBackgroundGradient(themeName, theme.brightness),
        ),
        // Without SafeArea, the bottom-most content (the day-detail panel)
        // can render underneath the system gesture bar / home button area on
        // devices with gesture navigation, since Scaffold doesn't inset its
        // body for that automatically.
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.chevron_left),
                      tooltip: '이전 달',
                      onPressed: () => _changeMonth(-1),
                    ),
                    Expanded(
                      child: Center(
                        child: Text('$year년 $month월',
                            style: theme.textTheme.titleMedium),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      tooltip: '다음 달',
                      onPressed: () => _changeMonth(1),
                    ),
                    TextButton(
                      onPressed: _goToToday,
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('오늘'),
                    ),
                  ],
                ),
              ),
              const _WeekdayHeader(),
              Expanded(
                flex: 3,
                child: GridView.count(
                  crossAxisCount: 7,
                  padding: const EdgeInsets.all(8),
                  children: cells,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 2),
                child: const Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: [
                    _LegendDot(color: Colors.green, label: '완료'),
                    _LegendDot(color: Colors.redAccent, label: '놓침'),
                    _LegendDot(color: Colors.amber, label: '오늘 (진행 중)'),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
                child: Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  children: const [
                    _PillLegendItem(taken: true, label: '알약 + X = 복용함'),
                    _PillLegendItem(taken: false, label: '알약만 = 복용 안 함'),
                  ],
                ),
              ),
              // Always visible (not a popup) — it just updates to whichever
              // day was last tapped, so the detail stays on screen rather
              // than needing to be dismissed before picking another day.
              Expanded(
                flex: 2,
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 2, 12, 12),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: _DayDetailPanel(day: _selectedDay, items: items),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayDetailPanel extends StatelessWidget {
  final DateTime? day;
  final List<MedicationItem> items;

  const _DayDetailPanel({required this.day, required this.items});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = this.day;
    if (day == null) {
      return Center(
        child: Text(
          '날짜를 선택하면 복용 내역이 표시돼요',
          style: theme.textTheme.bodySmall,
        ),
      );
    }

    final missed = missedItemsFor(day, items);
    final taken = takenItemsFor(day, items);
    final isToday = dateOnly(day) == dateOnly(DateTime.now());

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${day.year}년 ${day.month}월 ${day.day}일${isToday ? ' (오늘)' : ''}',
                  style: theme.textTheme.titleMedium?.copyWith(fontSize: 15.5),
                ),
              ),
              if (taken.isNotEmpty || missed.isNotEmpty)
                Text(
                  '${taken.length} / ${taken.length + missed.length} 복용',
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (taken.isEmpty && missed.isEmpty)
            const Text('등록된 약이 없어요')
          else ...[
            if (taken.isNotEmpty) ...[
              Text('복용함', style: theme.textTheme.titleSmall?.copyWith(fontSize: 13)),
              const SizedBox(height: 6),
              for (final item in taken)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          size: 18, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item.name)),
                    ],
                  ),
                ),
            ],
            if (taken.isNotEmpty && missed.isNotEmpty) const SizedBox(height: 12),
            if (missed.isNotEmpty) ...[
              Text(
                isToday ? '아직 안 먹었어요' : '복용 안 함',
                style: theme.textTheme.titleSmall?.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 6),
              for (final item in missed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Icon(
                        isToday ? Icons.radio_button_unchecked : Icons.cancel_outlined,
                        size: 18,
                        color: isToday ? Colors.amber.shade700 : Colors.redAccent,
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(item.name)),
                    ],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    const labels = ['일', '월', '화', '수', '목', '금', '토'];
    final base = Theme.of(context).colorScheme.onSurfaceVariant;
    // Korean calendar convention: Sunday red, Saturday blue.
    Color colorFor(int index) => switch (index) {
          0 => const Color(0xFFD05B5B),
          6 => const Color(0xFF4A6FD0),
          _ => base,
        };
    return Row(
      children: [
        for (int i = 0; i < labels.length; i++)
          Expanded(
            child: Center(
              child: Text(
                labels[i],
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: colorFor(i),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime date;
  final DayStatus status;
  final List<bool> pillFlags;
  final bool isToday;
  final bool selected;
  final VoidCallback onTap;

  /// A day cell is small, so pills beyond this count are simply dropped —
  /// no "+N" overflow badge, per how this was asked for.
  static const _maxPillIcons = 4;

  const _DayCell({
    required this.date,
    required this.status,
    required this.pillFlags,
    required this.isToday,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color? bg, Color textColor) = switch (status) {
      DayStatus.complete => (Colors.green.withValues(alpha: 0.25), Colors.black87),
      DayStatus.missed => (Colors.redAccent.withValues(alpha: 0.25), Colors.black87),
      DayStatus.pending => (Colors.amber.withValues(alpha: 0.3), Colors.black87),
      DayStatus.future ||
      DayStatus.noData =>
        (null, scheme.onSurfaceVariant.withValues(alpha: 0.55)),
    };
    final tappable = status == DayStatus.complete ||
        status == DayStatus.missed ||
        status == DayStatus.pending;
    // Future days would otherwise show every medication as a red "not
    // taken" capsule — noise about days that haven't happened yet.
    final shownPills = status == DayStatus.future
        ? const Iterable<bool>.empty()
        : pillFlags.take(_maxPillIcons);

    return GestureDetector(
      onTap: tappable ? onTap : null,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: selected
              ? Border.all(color: scheme.primary, width: 2)
              : isToday
                  ? Border.all(
                      color: scheme.primary.withValues(alpha: 0.55),
                      width: 1.3,
                    )
                  : null,
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                color: textColor,
                fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (shownPills.isNotEmpty) ...[
              const SizedBox(height: 2),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 1,
                runSpacing: 1,
                children: [for (final taken in shownPills) _PillIcon(taken: taken)],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One medication's taken/missed status for a day, drawn as an actual
/// capsule shape (not the abstract `Icons.medication` glyph, which reads
/// too faint at this size) — an X through it when taken, plain when not.
class _PillIcon extends StatelessWidget {
  final bool taken;
  const _PillIcon({required this.taken});

  @override
  Widget build(BuildContext context) {
    final color = taken ? Colors.green : Colors.redAccent;
    return SizedBox(
      width: 13,
      height: 13,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 13,
            height: 6.5,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3.25),
            ),
          ),
          if (taken) const Icon(Icons.close, size: 11, color: Colors.white),
        ],
      ),
    );
  }
}

/// Explains the calendar's pill-icon convention — an X normally reads as
/// "not done", so this is called out explicitly rather than left implicit.
class _PillLegendItem extends StatelessWidget {
  final bool taken;
  final String label;
  const _PillLegendItem({required this.taken, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PillIcon(taken: taken),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
