import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/medication_item.dart';
import '../models/medication_state.dart';
import '../services/adherence.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _visibleMonth = DateTime(DateTime.now().year, DateTime.now().month);

  void _changeMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    });
  }

  void _showDayDetail(DateTime day, List<MedicationItem> items) {
    final missed = missedItemsFor(day, items);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${day.year}년 ${day.month}월 ${day.day}일',
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: 12),
              if (missed.isEmpty)
                const Text('모두 완료했어요 🎉')
              else ...[
                const Text('놓친 약'),
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
            onTap: () => _showDayDetail(date, items),
          );
        }),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('복약 달력')),
      body: Column(
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
            child: GridView.count(
              crossAxisCount: 7,
              padding: const EdgeInsets.all(8),
              children: cells,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: const Wrap(
              spacing: 16,
              children: [
                _LegendDot(color: Colors.green, label: '완료'),
                _LegendDot(color: Colors.redAccent, label: '놓침'),
              ],
            ),
          ),
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
  final VoidCallback onTap;

  const _DayCell({required this.date, required this.status, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (Color? bg, Color textColor) = switch (status) {
      DayStatus.complete => (Colors.green.withValues(alpha: 0.25), Colors.black87),
      DayStatus.missed => (Colors.redAccent.withValues(alpha: 0.25), Colors.black87),
      DayStatus.future || DayStatus.noData => (null, Colors.grey),
    };
    final tappable = status == DayStatus.complete || status == DayStatus.missed;

    return GestureDetector(
      onTap: tappable ? onTap : null,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        alignment: Alignment.center,
        child: Text('${date.day}', style: TextStyle(color: textColor)),
      ),
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
