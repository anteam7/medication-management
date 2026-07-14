import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/alarm_style.dart';
import '../models/meal_timing.dart';
import '../models/medication_item.dart';
import '../models/time_slot.dart';
import '../services/speech_service.dart';
import '../utils/date_key.dart';
import '../widgets/simple_date_picker.dart';
import '../widgets/simple_time_picker.dart';

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
  final Map<String, int> _alarmTimes = {};
  AlarmStyle _alarmStyle = AlarmStyle.gentleSound;
  late final TextEditingController _memoController =
      TextEditingController(text: widget.existing?.memo ?? '');
  // Which field a listening session (if any) is currently dictating into —
  // only one mic can be active at a time, so this alone drives both
  // buttons' visual state.
  String? _listeningField;

  @override
  void initState() {
    super.initState();
    final existingSlots = widget.existing?.timeSlots;
    if (existingSlots != null) _selectedSlots.addAll(existingSlots);
    _selectedMealTiming = widget.existing?.mealTiming;
    _receivedDate = widget.existing?.receivedDate;
    final existingAlarms = widget.existing?.alarmTimes;
    if (existingAlarms != null) _alarmTimes.addAll(existingAlarms);
    _alarmStyle = widget.existing?.alarmStyle ?? AlarmStyle.gentleSound;
  }

  /// Toggles voice dictation into [controller]. If a different field is
  /// currently listening, that session is stopped and this one starts in
  /// its place — only one mic can be active at once.
  Future<void> _toggleListening(String field, TextEditingController controller) async {
    if (SpeechService.instance.isListening) {
      await SpeechService.instance.stopListening();
      if (_listeningField == field) return;
    }
    final available = await SpeechService.instance.init();
    if (!available) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('음성 인식을 사용할 수 없습니다')));
      }
      return;
    }
    await SpeechService.instance.startListening(
      onResult: (text) {
        if (!mounted) return;
        controller.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      },
      onListeningChange: (listening) {
        if (mounted) setState(() => _listeningField = listening ? field : null);
      },
    );
    setState(() => _listeningField = field);
  }

  /// The slot keys this medication is currently assigned to — [anySlotKey]
  /// stands in when no specific time-of-day is selected.
  List<String> _activeSlotKeys() =>
      _selectedSlots.isEmpty ? [anySlotKey] : _selectedSlots.map((s) => s.name).toList();

  String _slotKeyLabel(String key) =>
      key == anySlotKey ? '기본' : TimeSlot.values.firstWhere((s) => s.name == key).label;

  Future<void> _pickAlarmTime(String slotKey) async {
    final picked = await showSimpleTimePicker(context, initialMinutes: _alarmTimes[slotKey]);
    if (picked != null) setState(() => _alarmTimes[slotKey] = picked);
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
    if (SpeechService.instance.isListening) {
      SpeechService.instance.stopListening();
    }
    _nameController.dispose();
    _memoController.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 85);
    if (file != null) setState(() => _pickedPhoto = file);
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    // Drop alarms for slots that are no longer assigned to this medication
    // so a deselected time slot doesn't leave a "ghost" alarm behind.
    final activeKeys = _activeSlotKeys().toSet();
    _alarmTimes.removeWhere((key, _) => !activeKeys.contains(key));
    Navigator.pop(
      context,
      (
        name: name,
        photo: _pickedPhoto,
        timeSlots: _selectedSlots,
        mealTiming: _selectedMealTiming,
        receivedDate: _receivedDate,
        alarmTimes: _alarmTimes,
        alarmStyle: _alarmStyle,
        memo: _memoController.text.trim().isEmpty ? null : _memoController.text.trim(),
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
          const SizedBox(height: 4),
          const Text('* 필수 입력 항목', style: TextStyle(color: Colors.redAccent, fontSize: 11)),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _nameController,
                    autofocus: !isEdit,
                    decoration: InputDecoration(
                      label: const Text.rich(
                        TextSpan(
                          text: '약 이름',
                          children: [
                            TextSpan(text: ' *', style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _listeningField == 'name' ? '녹음 중지' : '음성으로 입력',
                        icon: Icon(
                          _listeningField == 'name' ? Icons.mic : Icons.mic_none,
                          color: _listeningField == 'name' ? Colors.redAccent : null,
                        ),
                        onPressed: () => _toggleListening('name', _nameController),
                      ),
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
                    child: Text('알람 (시간대별로 설정, 안 하면 알람 없음)',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  const SizedBox(height: 6),
                  for (final slotKey in _activeSlotKeys())
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          SizedBox(width: 48, child: Text(_slotKeyLabel(slotKey))),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _pickAlarmTime(slotKey),
                              icon: const Icon(Icons.alarm, size: 16),
                              label: Text(
                                _alarmTimes[slotKey] == null
                                    ? '알람 없음'
                                    : formatMinutes(_alarmTimes[slotKey]!),
                              ),
                            ),
                          ),
                          if (_alarmTimes[slotKey] != null)
                            IconButton(
                              tooltip: '알람 끄기',
                              icon: const Icon(Icons.close),
                              onPressed: () => setState(() => _alarmTimes.remove(slotKey)),
                            ),
                        ],
                      ),
                    ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('알림 방식', style: Theme.of(context).textTheme.bodySmall),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: AlarmStyle.values.map((style) {
                      final selected = _alarmStyle == style;
                      return ChoiceChip(
                        label: Text(style.label),
                        selected: selected,
                        onSelected: (_) => setState(() => _alarmStyle = style),
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
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('메모 (마이크로 말하면 텍스트로 변환됩니다)',
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _memoController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText:
                          _listeningField == 'memo' ? '듣고 있어요…' : '메모를 입력하거나 마이크를 눌러 말하세요',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                        tooltip: _listeningField == 'memo' ? '녹음 중지' : '음성으로 입력',
                        icon: Icon(
                          _listeningField == 'memo' ? Icons.mic : Icons.mic_none,
                          color: _listeningField == 'memo' ? Colors.redAccent : null,
                        ),
                        onPressed: () => _toggleListening('memo', _memoController),
                      ),
                    ),
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
