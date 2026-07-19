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
    try {
      final file = await _picker.pickImage(source: source, imageQuality: 85);
      if (file != null) setState(() => _pickedPhoto = file);
    } catch (_) {
      // Permission denied / camera unavailable — tell the user instead of
      // leaving the button silently unresponsive.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('사진을 가져올 수 없어요. 권한을 확인해주세요')),
        );
      }
    }
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

  Widget _micButton(String field, TextEditingController controller) {
    final listening = _listeningField == field;
    return IconButton(
      tooltip: listening ? '녹음 중지' : '음성으로 입력',
      icon: Icon(
        listening ? Icons.mic : Icons.mic_none,
        color: listening ? Theme.of(context).colorScheme.error : null,
      ),
      onPressed: () => _toggleListening(field, controller),
    );
  }

  Widget _photoPreview(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = Container(
      height: 110,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined,
              size: 28, color: theme.colorScheme.primary),
          const SizedBox(height: 6),
          Text('아직 등록된 사진이 없어요', style: theme.textTheme.bodySmall),
        ],
      ),
    );

    final pickedPath = _pickedPhoto?.path ?? widget.existing?.referencePhotoPath;
    if (pickedPath == null) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Image.file(
        File(pickedPath),
        height: 150,
        width: double.infinity,
        fit: BoxFit.cover,
        // A stale path (photo file cleaned up outside this sheet) falls
        // back to the empty-photo card instead of a render error.
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    final theme = Theme.of(context);

    return Padding(
      // Top padding is small because the modal sheet now shows a drag
      // handle above this content.
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The submit button lives up here, next to the title, so it's
          // always in easy reach — below every field it ends up pushed near
          // the bottom of the screen (or behind the keyboard).
          Row(
            children: [
              Expanded(
                child: Text(isEdit ? '약 정보 수정' : '약 추가',
                    style: theme.textTheme.titleMedium),
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
                    decoration: InputDecoration(
                      label: Text.rich(
                        TextSpan(
                          text: '약 이름',
                          children: [
                            TextSpan(
                              text: ' *',
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ],
                        ),
                      ),
                      suffixIcon: _micButton('name', _nameController),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _SectionLabel(
                    icon: Icons.schedule_outlined,
                    label: '복용 시간대',
                    hint: '선택 안 하면 하루 1번 체크',
                  ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 18),
                  const _SectionLabel(
                    icon: Icons.notifications_none_rounded,
                    label: '알람',
                    hint: '시간대별 설정, 안 하면 알람 없음',
                  ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 12),
                  const _SectionLabel(
                    icon: Icons.volume_up_outlined,
                    label: '알림 방식',
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: AlarmStyle.values.map((style) {
                      final selected = _alarmStyle == style;
                      return ChoiceChip(
                        label: Text(style.label),
                        selected: selected,
                        onSelected: (_) => setState(() => _alarmStyle = style),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 18),
                  const _SectionLabel(
                    icon: Icons.restaurant_outlined,
                    label: '식전 / 식후',
                    hint: '선택 안 하면 상관없음',
                  ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 18),
                  const _SectionLabel(
                    icon: Icons.event_available_outlined,
                    label: '약 받은 날',
                    hint: '선택 안 해도 돼요',
                  ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 18),
                  const _SectionLabel(
                    icon: Icons.photo_camera_outlined,
                    label: '약 사진',
                    hint: '인증사진 비교의 기준이 돼요',
                  ),
                  const SizedBox(height: 8),
                  _photoPreview(context),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pick(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: const Text('촬영'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pick(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library_outlined, size: 18),
                          label: const Text('갤러리'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  const _SectionLabel(
                    icon: Icons.sticky_note_2_outlined,
                    label: '메모',
                    hint: '마이크를 누르면 음성으로 입력돼요',
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _memoController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: _listeningField == 'memo'
                          ? '듣고 있어요…'
                          : '메모를 입력하거나 마이크를 눌러 말하세요',
                      suffixIcon: _micButton('memo', _memoController),
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

/// Icon + title heading for each form section — the icon gives every block
/// a quick visual anchor, the optional hint keeps helper text on one line
/// with the label instead of floating loose.
class _SectionLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? hint;
  const _SectionLabel({required this.icon, required this.label, this.hint});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.primary),
        const SizedBox(width: 5),
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(fontSize: 13.5),
        ),
        if (hint != null) ...[
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              hint!,
              style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );
  }
}
