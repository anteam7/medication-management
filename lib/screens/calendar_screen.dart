import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/medication_item.dart';
import '../models/medication_state.dart';
import '../models/time_slot.dart';
import '../services/adherence.dart';
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
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
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
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text('${item.name}: ${_alarmSummary(item)}'),
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
    final year = _visibleMonth.year;
    final month = _visibleMonth.month;
    final firstOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    // DateTime.weekday: Monday=1..Sunday=7 — we want a Sunday-first grid.
    final leadingBlanks = firstOfMonth.weekday % 7;

    final cells = <Widget>[
      for (int i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
      for (int day = 1; day <= daysInMonth; day++)
        Builder(builder: (context) {
          final date = DateTime(year, month, day);
          return _DayCell(
            date: date,
            status: dayStatusFor(date, items),
            pillFlags: dailyStatusFlags(date, items),
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
      // Without this, the bottom-most content (the day-detail panel's text)
      // can render underneath the system gesture bar / home button area on
      // devices with gesture navigation, since Scaffold doesn't inset its
      // body for that automatically.
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _changeMonth(-1),
                  ),
                  Text('$year년 $month월', style: Theme.of(context).textTheme.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _changeMonth(1),
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
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: const Wrap(
                spacing: 16,
                runSpacing: 4,
                children: [
                  _LegendDot(color: Colors.green, label: '완료'),
                  _LegendDot(color: Colors.redAccent, label: '놓침'),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Wrap(
                spacing: 16,
                runSpacing: 4,
                children: const [
                  _PillLegendItem(taken: true, label: '알약 + X = 복용함'),
                  _PillLegendItem(taken: false, label: '알약만 = 복용 안 함'),
                ],
              ),
            ),
            const Divider(height: 1),
            // Always visible (not a popup) — it just updates to whichever day
            // was last tapped, so the detail stays on screen rather than
            // needing to be dismissed before picking another day.
            Expanded(
              flex: 2,
              child: _DayDetailPanel(day: _selectedDay, items: items),
            ),
          ],
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
    final day = this.day;
    if (day == null) {
      return const Center(
        child: Text('날짜를 선택하면 복용 내역이 표시돼요', style: TextStyle(color: Colors.grey)),
      );
    }

    final missed = missedItemsFor(day, items);
    final taken = takenItemsFor(day, items);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${day.year}년 ${day.month}월 ${day.day}일',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          if (taken.isEmpty && missed.isEmpty)
            const Text('등록된 약이 없어요')
          else ...[
            if (taken.isNotEmpty) ...[
              const Text('복용함'),
              const SizedBox(height: 8),
              for (final item in taken)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, size: 18, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(item.name),
                    ],
                  ),
                ),
            ],
            if (taken.isNotEmpty && missed.isNotEmpty) const SizedBox(height: 12),
            if (missed.isNotEmpty) ...[
              const Text('복용 안 함'),
              const SizedBox(height: 8),
              for (final item in missed)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.cancel_outlined, size: 18, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Text(item.name),
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
    return Row(
      children: [
        for (final l in labels)
          Expanded(
            child: Center(
              child: Text(l, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
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
  final VoidCallback onTap;

  /// A day cell is small, so pills beyond this count are simply dropped —
  /// no "+N" overflow badge, per how this was asked for.
  static const _maxPillIcons = 4;

  const _DayCell({
    required this.date,
    required this.status,
    required this.pillFlags,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (Color? bg, Color textColor) = switch (status) {
      DayStatus.complete => (Colors.green.withValues(alpha: 0.25), Colors.black87),
      DayStatus.missed => (Colors.redAccent.withValues(alpha: 0.25), Colors.black87),
      DayStatus.future || DayStatus.noData => (null, Colors.grey),
    };
    final tappable = status == DayStatus.complete || status == DayStatus.missed;
    final shownPills = pillFlags.take(_maxPillIcons);

    return GestureDetector(
      onTap: tappable ? onTap : null,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${date.day}', style: TextStyle(color: textColor)),
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
