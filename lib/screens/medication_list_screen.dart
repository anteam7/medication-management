import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/meal_timing.dart';
import '../models/medication_item.dart';
import '../models/medication_state.dart';
import '../models/time_slot.dart';
import '../utils/date_key.dart';
import 'add_medication_sheet.dart';
import 'calendar_screen.dart';

typedef _AddResult = ({
  String name,
  XFile? photo,
  Set<TimeSlot> timeSlots,
  MealTiming? mealTiming,
  DateTime? receivedDate,
});

class MedicationListScreen extends StatelessWidget {
  const MedicationListScreen({super.key});

  Future<void> _openAddSheet(BuildContext context, {MedicationItem? existing}) async {
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
      );
    } else {
      await state.editItem(
        existing.id,
        newName: result.name,
        newReferencePhoto: result.photo,
        newTimeSlots: result.timeSlots,
        newMealTiming: result.mealTiming,
        newReceivedDate: result.receivedDate,
      );
    }
  }

  Future<void> _confirmWithPhoto(BuildContext context, MedicationItem item, TimeSlot? slot) async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (photo == null || !context.mounted) return;
    await context.read<MedicationState>().completeToday(item.id, slot: slot, proofPhoto: photo);
  }

  void _showItemMenu(BuildContext context, MedicationItem item) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('수정'),
              onTap: () {
                Navigator.pop(ctx);
                _openAddSheet(context, existing: item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.redAccent),
              title: const Text('삭제', style: TextStyle(color: Colors.redAccent)),
              onTap: () async {
                Navigator.pop(ctx);
                await _deleteItem(context, item);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Confirms then removes [item] entirely — including its other time-slot
  /// sections, reference photo and full completion history.
  Future<bool> _deleteItem(BuildContext context, MedicationItem item) async {
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
    if (confirmed != true) return false;
    if (context.mounted) {
      await context.read<MedicationState>().removeItem(item.id);
    }
    return true;
  }

  /// Items belonging to [slot] (or items with no time-of-day assigned, when
  /// [slot] is null) — a medication assigned to multiple slots shows up in
  /// each of its sections, checked off independently.
  List<MedicationItem> _itemsForSlot(List<MedicationItem> items, TimeSlot? slot) {
    return items.where((item) {
      return slot == null ? item.timeSlots.isEmpty : item.timeSlots.contains(slot);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MedicationState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('복약 관리'),
        actions: [
          IconButton(
            tooltip: '복약 달력',
            icon: const Icon(Icons.calendar_month),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CalendarScreen()),
            ),
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
                    for (final slot in [TimeSlot.morning, TimeSlot.lunch, TimeSlot.evening, null])
                      ..._buildSection(context, state, slot),
                  ],
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openAddSheet(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  List<Widget> _buildSection(BuildContext context, MedicationState state, TimeSlot? slot) {
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
          confirmDismiss: (_) => _deleteItem(context, item),
          child: _MedicationTile(
            item: item,
            done: state.isCompletedForSlot(item, slot),
            onTapCheck: () {
              final s = context.read<MedicationState>();
              state.isCompletedForSlot(item, slot)
                  ? s.uncompleteToday(item.id, slot: slot)
                  : s.completeToday(item.id, slot: slot);
            },
            onPhotoCheck: () => _confirmWithPhoto(context, item, slot),
            onLongPress: () => _showItemMenu(context, item),
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
  final VoidCallback onTapCheck;
  final VoidCallback onPhotoCheck;
  final VoidCallback onLongPress;

  const _MedicationTile({
    required this.item,
    required this.done,
    required this.onTapCheck,
    required this.onPhotoCheck,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        onLongPress: onLongPress,
        leading: CircleAvatar(
          radius: 22,
          backgroundImage: item.referencePhotoPath != null
              ? FileImage(File(item.referencePhotoPath!))
              : null,
          child: item.referencePhotoPath == null ? const Icon(Icons.medication) : null,
        ),
        title: Text(
          item.name,
          style: done
              ? const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)
              : null,
        ),
        subtitle: Text([
          if (item.mealTiming != null) item.mealTiming!.label,
          done ? '오늘 완료 ✅' : '오늘 미완료',
          if (item.receivedDate != null) '받은날 ${dateKey(item.receivedDate!)}',
        ].join(' · ')),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '사진으로 확인',
              icon: const Icon(Icons.camera_alt_outlined),
              onPressed: onPhotoCheck,
            ),
            IconButton(
              tooltip: done ? '완료 취소' : '체크',
              icon: Icon(
                done ? Icons.check_circle : Icons.check_circle_outline,
                color: done ? Colors.green : null,
              ),
              onPressed: onTapCheck,
            ),
          ],
        ),
      ),
    );
  }
}
