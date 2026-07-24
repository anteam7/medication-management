import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_theme.dart';
import '../models/app_theme_state.dart';
import '../models/medication_item.dart';
import '../models/medication_state.dart';
import '../models/time_slot.dart';
import '../services/adherence.dart';

/// "기간별 복약 성취" leads with a single aggregate — "오늘 먹어야 할 전체 약의
/// 상황" (today's combined status across every course-bound medication) and
/// "전체 기간 중에 진행된 사항" (combined progress across their whole course
/// periods) — followed by a simple daily check per medication below, since
/// the aggregate alone gives no way to actually mark today's doses from this
/// screen. That per-medication check is purely a "today" check — it's keyed
/// off the same daily completion record as the rest of the app, so it
/// resets on its own the moment a new day starts, same as everywhere else.
class AchievementScreen extends StatelessWidget {
  const AchievementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MedicationState>();
    final allItems = state.items;
    final items = allItems.where((i) => i.courseEndDate != null).toList();
    final themeName = context.watch<AppThemeState>().current;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('기간별 복약 성취')),
      body: Container(
        decoration: BoxDecoration(
          gradient: appBackgroundGradient(themeName, theme.brightness),
        ),
        child: items.isEmpty
            ? Center(
                child: Text(
                  allItems.isEmpty ? '등록된 약이 없어요' : '기간이 설정된 약이 없어요',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _AggregateRateCard(items: items),
                  const SizedBox(height: 24),
                  Text('오늘 체크', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 8),
                  for (final item in items) _DailyCheckRow(item: item),
                ],
              ),
      ),
    );
  }
}

/// The full-width aggregate bar. "오늘" used to have its own bar here too,
/// but that duplicated the today progress already shown at the top of the
/// main medication list screen, so this card now only covers the whole
/// course period.
class _AggregateRateCard extends StatelessWidget {
  final List<MedicationItem> items;
  const _AggregateRateCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      padding: const EdgeInsets.all(16),
      child: _RateBlockBar(label: '전체 기간', rate: aggregateCourseRateFor(items)),
    );
  }
}

/// A progress bar on the left with its label + percentage grouped into a
/// same-size block on the right, so "오늘" and "전체 기간" line up identically
/// regardless of value.
class _RateBlockBar extends StatelessWidget {
  final String label;
  final double? rate;
  const _RateBlockBar({required this.label, required this.rate});

  // Sized for the longest realistic single line ("전체 기간 100%") at these
  // font sizes.
  static const _blockWidth = 128.0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rate = this.rate;
    final value = rate ?? 0;
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 16,
              color: scheme.primary,
              backgroundColor: scheme.primary.withValues(alpha: 0.15),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: _blockWidth,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                rate == null ? '-' : '${(rate * 100).round()}%',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One medication's simple today-only check — tapping marks/clears every
/// slot it has for today at once. Read from and written to the exact same
/// per-day completion record the rest of the app uses, so it's naturally in
/// sync with the main list's own checks and resets the moment today's date
/// key changes.
class _DailyCheckRow extends StatelessWidget {
  final MedicationItem item;
  const _DailyCheckRow({required this.item});

  List<TimeSlot?> get _slots =>
      item.timeSlots.isEmpty ? const [null] : item.timeSlots.map((s) => s as TimeSlot?).toList();

  Future<void> _toggle(BuildContext context, bool currentlyDone) async {
    final state = context.read<MedicationState>();
    for (final slot in _slots) {
      if (currentlyDone) {
        await state.uncompleteToday(item.id, slot: slot);
      } else {
        await state.completeToday(item.id, slot: slot);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MedicationState>();
    final done = state.isFullyCompletedToday(item);
    final scheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _toggle(context, done),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done ? Colors.green : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done ? scheme.onSurfaceVariant : scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
