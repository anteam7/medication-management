import 'package:flutter/material.dart';

/// A minimal, fully-numeric month-grid date picker. Flutter's built-in
/// `showDatePicker` renders spelled-out English month names and weekday
/// abbreviations unless the whole app is localized, so this small
/// self-contained picker is used instead wherever a plain numeric calendar
/// is wanted.
Future<DateTime?> showSimpleDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return showDialog<DateTime>(
    context: context,
    builder: (_) => _SimpleDatePickerDialog(
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
    ),
  );
}

class _SimpleDatePickerDialog extends StatefulWidget {
  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;

  const _SimpleDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
  });

  @override
  State<_SimpleDatePickerDialog> createState() => _SimpleDatePickerDialogState();
}

class _SimpleDatePickerDialogState extends State<_SimpleDatePickerDialog> {
  late DateTime _visibleMonth = DateTime(widget.initialDate.year, widget.initialDate.month);
  late DateTime _selected = widget.initialDate;

  void _changeMonth(int delta) {
    final next = DateTime(_visibleMonth.year, _visibleMonth.month + delta);
    final minMonth = DateTime(widget.firstDate.year, widget.firstDate.month);
    final maxMonth = DateTime(widget.lastDate.year, widget.lastDate.month);
    if (next.isBefore(minMonth) || next.isAfter(maxMonth)) return;
    setState(() => _visibleMonth = next);
  }

  @override
  Widget build(BuildContext context) {
    final year = _visibleMonth.year;
    final month = _visibleMonth.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final leadingBlanks = DateTime(year, month, 1).weekday % 7;
    final monthLabel = '$year.${month.toString().padLeft(2, '0')}';

    return AlertDialog(
      contentPadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
          Text(monthLabel),
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
        ],
      ),
      content: SizedBox(
        width: 300,
        height: 280,
        child: Column(
          children: [
            Row(
              children: [
                for (final (i, w) in const ['일', '월', '화', '수', '목', '금', '토'].indexed)
                  Expanded(
                    child: Center(
                      child: Text(
                        w,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          // Korean calendar convention: Sunday red, Saturday blue.
                          color: switch (i) {
                            0 => const Color(0xFFD05B5B),
                            6 => const Color(0xFF4A6FD0),
                            _ => Theme.of(context).colorScheme.onSurfaceVariant,
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Expanded(
              child: GridView.count(
                crossAxisCount: 7,
                children: [
                  for (int i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
                  for (int day = 1; day <= daysInMonth; day++)
                    Builder(builder: (context) {
                      final date = DateTime(year, month, day);
                      final isSelected = date.year == _selected.year &&
                          date.month == _selected.month &&
                          date.day == _selected.day;
                      final disabled = date.isBefore(widget.firstDate) || date.isAfter(widget.lastDate);
                      final scheme = Theme.of(context).colorScheme;
                      return GestureDetector(
                        onTap: disabled ? null : () => setState(() => _selected = date),
                        child: Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: isSelected ? scheme.primary : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '$day',
                            style: TextStyle(
                              fontWeight:
                                  isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: disabled
                                  ? scheme.onSurfaceVariant.withValues(alpha: 0.35)
                                  : (isSelected ? scheme.onPrimary : null),
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(onPressed: () => Navigator.pop(context, _selected), child: const Text('확인')),
      ],
    );
  }
}
