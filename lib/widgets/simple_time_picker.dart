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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('알람 시간'),
      content: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          DropdownButton<int>(
            value: _hour,
            items: [
              for (int h = 0; h < 24; h++)
                DropdownMenuItem(value: h, child: Text(h.toString().padLeft(2, '0'))),
            ],
            onChanged: (v) => setState(() => _hour = v!),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text(':', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          DropdownButton<int>(
            value: _minute,
            items: [
              for (int m = 0; m < 60; m++)
                DropdownMenuItem(value: m, child: Text(m.toString().padLeft(2, '0'))),
            ],
            onChanged: (v) => setState(() => _minute = v!),
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
