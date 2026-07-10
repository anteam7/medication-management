import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/meal_timing.dart';
import '../models/medication_item.dart';
import '../models/time_slot.dart';
import '../utils/date_key.dart';
import '../widgets/simple_date_picker.dart';

/// Bottom sheet used for both adding a new medication and editing an
/// existing one — pass [existing] to pre-fill the name/photo for edit mode.
class AddMedicationSheet extends StatefulWidget {
  final MedicationItem? existing;
  const AddMedicationSheet({super.key, this.existing});

  @override
  State<AddMedicationSheet> createState() => _AddMedicationSheetState();
}

class _AddMedicationSheetState extends State<AddMedicationSheet> {
  late final TextEditingController _nameController =
      TextEditingController(text: widget.existing?.name ?? '');
  final ImagePicker _picker = ImagePicker();
  XFile? _pickedPhoto;
  final Set<TimeSlot> _selectedSlots = {};
  MealTiming? _selectedMealTiming;
  DateTime? _receivedDate;

  @override
  void initState() {
    super.initState();
    final existingSlots = widget.existing?.timeSlots;
    if (existingSlots != null) _selectedSlots.addAll(existingSlots);
    _selectedMealTiming = widget.existing?.mealTiming;
    _receivedDate = widget.existing?.receivedDate;
  }

  Future<void> _pickReceivedDate() async {
    final now = DateTime.now();
    final picked = await showSimpleDatePicker(
      context,
      initialDate: _receivedDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => _receivedDate = picked);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 85);
    if (file != null) setState(() => _pickedPhoto = file);
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
      context,
      (
        name: name,
        photo: _pickedPhoto,
        timeSlots: _selectedSlots,
        mealTiming: _selectedMealTiming,
        receivedDate: _receivedDate,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final existingPhotoPath = widget.existing?.referencePhotoPath;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The submit button lives up here, next to the title, so it's
          // always in easy reach — previously it sat below every field and
          // ended up pushed near the bottom of the screen (or behind the
          // keyboard) once the form grew.
          Row(
            children: [
              Expanded(
                child: Text(isEdit ? '약 정보 수정' : '약 추가',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              FilledButton(
                onPressed: _submit,
                child: Text(isEdit ? '저장' : '추가'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameController,
                    autofocus: !isEdit,
                    decoration: const InputDecoration(
                      labelText: '약 이름',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('복용 시간대 (선택 안 하면 하루 1번 체크)',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: TimeSlot.values.map((slot) {
                      final selected = _selectedSlots.contains(slot);
                      return FilterChip(
                        label: Text(slot.label),
                        selected: selected,
                        onSelected: (value) => setState(() {
                          if (value) {
                            _selectedSlots.add(slot);
                          } else {
                            _selectedSlots.remove(slot);
                          }
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('식전 / 식후 (선택 안 하면 상관없음)',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: MealTiming.values.map((timing) {
                      final selected = _selectedMealTiming == timing;
                      return ChoiceChip(
                        label: Text(timing.label),
                        selected: selected,
                        onSelected: (value) => setState(() {
                          _selectedMealTiming = value ? timing : null;
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('약 받은 날 (선택 안 해도 됨)',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickReceivedDate,
                          icon: const Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            _receivedDate == null ? '날짜 선택' : dateKey(_receivedDate!),
                          ),
                        ),
                      ),
                      if (_receivedDate != null)
                        IconButton(
                          tooltip: '날짜 지우기',
                          icon: const Icon(Icons.close),
                          onPressed: () => setState(() => _receivedDate = null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_pickedPhoto != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(_pickedPhoto!.path),
                          height: 140, fit: BoxFit.cover),
                    )
                  else if (existingPhotoPath != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(File(existingPhotoPath),
                          height: 140, fit: BoxFit.cover),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('촬영'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pick(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('갤러리'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
