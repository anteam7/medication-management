import 'package:flutter/material.dart';

/// A minimal 24-hour, numbers-only time picker. Flutter's built-in
/// `showTimePicker` mixes in English AM/PM unless the whole app is
/// localized, so this small dialog is used instead — consistent with
/// [showSimpleDatePicker].
///
/// Returns the picked time as minutes since midnight (0..1439), or null if
/// cancelled.
Future<int?> showSimpleTimePicker(
  BuildContext context, {
  int? initialMinutes,
}) {
  final initial = initialMinutes ?? 8 * 60;
  return showDialog<int>(
    context: context,
    builder: (_) => _SimpleTimePickerDialog(initialMinutes: initial),
  );
}

String formatMinutes(int minutes) {
  final h = (minutes ~/ 60).toString().padLeft(2, '0');
  final m = (minutes % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

class _SimpleTimePickerDialog extends StatefulWidget {
  final int initialMinutes;
  const _SimpleTimePickerDialog({required this.initialMinutes});

  @override
  State<_SimpleTimePickerDialog> createState() => _SimpleTimePickerDialogState();
}

class _SimpleTimePickerDialogState extends State<_SimpleTimePickerDialog> {
  late int _hour = widget.initialMinutes ~/ 60;
  late int _minute = widget.initialMinutes % 60;

  Widget _numberDropdown({
    required int value,
    required int count,
    required ValueChanged<int> onChanged,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<int>(
        value: value,
        underline: const SizedBox.shrink(),
        borderRadius: BorderRadius.circular(14),
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
        items: [
          for (int i = 0; i < count; i++)
            DropdownMenuItem(value: i, child: Text(i.toString().padLeft(2, '0'))),
        ],
        onChanged: (v) => onChanged(v!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('알람 시간'),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _numberDropdown(
            value: _hour,
            count: 24,
            onChanged: (v) => setState(() => _hour = v),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text(':', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ),
          _numberDropdown(
            value: _minute,
            count: 60,
            onChanged: (v) => setState(() => _minute = v),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
        TextButton(
          onPressed: () => Navigator.pop(context, _hour * 60 + _minute),
          child: const Text('확인'),
        ),
      ],
    );
  }
}
