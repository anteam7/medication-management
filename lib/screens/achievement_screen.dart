import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_theme.dart';
import '../models/app_theme_state.dart';
import '../models/medication_item.dart';
import '../models/medication_state.dart';
import '../services/adherence.dart';
import '../utils/date_key.dart';

/// Per-medication course progress: how far into its start~end date range it
/// is, its running adherence rate, current streak, and — once the course's
/// end date has passed — a completion badge. Only medications with a
/// defined course period ([MedicationItem.courseEndDate]) appear here — a
/// period-based percentage only means something when there's a "whole" to
/// measure against. Indefinite/chronic medications show up in the main
/// screen's today hero card instead, not here.
class AchievementScreen extends StatelessWidget {
  const AchievementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final allItems = context.watch<MedicationState>().items;
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
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) => _CourseCard(item: items[index]),
              ),
      ),
    );
  }
}

/// Only ever built for medications with a defined course period (see
/// [AchievementScreen]), so achievement always reads as "how much of the
/// whole course is done" — a full-width slide bar with its percentage.
class _CourseCard extends StatelessWidget {
  final MedicationItem item;
  const _CourseCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rate = adherenceRateFor(item);
    final streak = currentStreakFor(item);
    final completed = isCourseCompleted(item);

    final String badgeText;
    if (completed) {
      badgeText = '완주 ${((rate ?? 1) * 100).round()}%';
    } else {
      final remaining = daysBetween(dateOnly(DateTime.now()), dateOnly(item.courseEndDate!));
      badgeText = remaining >= 0 ? 'D-$remaining' : 'D+${-remaining}';
    }

    final String subtitle = completed
        ? '${courseDayCount(item)}일 코스 완료'
        : '${courseDayCount(item)}일 코스 · ${courseElapsedDay(item)}일차 진행 중';

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: completed ? scheme.primary : Theme.of(context).dividerColor,
          width: completed ? 2 : 1,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  item.name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: completed
                      ? scheme.primary.withValues(alpha: 0.14)
                      : scheme.onSurfaceVariant.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: completed ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          Text('전체 코스', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          _CourseSlideBar(rate: rate),
          const SizedBox(height: 10),
          // Today is shown separately from the whole-course rate above —
          // it's a different question ("did I take it today" vs. "how's
          // the whole course going").
          Text('오늘의 성취도', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 4),
          _CourseSlideBar(rate: todayExecutionRateFor(item)),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                completed ? Icons.emoji_events_outlined : Icons.local_fire_department_outlined,
                size: 15,
                color: scheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                completed ? '완주 뱃지 획득' : '$streak일 연속 복용',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: completed ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A linear "slide" progress bar with its percentage alongside — used for
/// both the whole-course rate and today's rate, so the two read as the same
/// visual language despite answering different questions.
class _CourseSlideBar extends StatelessWidget {
  final double? rate;
  const _CourseSlideBar({required this.rate});

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
              minHeight: 10,
              color: scheme.primary,
              backgroundColor: scheme.primary.withValues(alpha: 0.15),
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 42,
          child: Text(
            rate == null ? '-' : '${(rate * 100).round()}%',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurface),
          ),
        ),
      ],
    );
  }
}
