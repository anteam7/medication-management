import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_theme.dart';
import '../models/app_theme_state.dart';

Future<void> showThemePickerSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _ThemePickerSheet(),
  );
}

class _ThemePickerSheet extends StatelessWidget {
  const _ThemePickerSheet();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppThemeState>();
    final maxHeight = MediaQuery.of(context).size.height * 0.75;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('테마 선택', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 4),
              // The app pins ThemeMode.light in main.dart — the themes are
              // designed as light-mode looks and never follow system dark
              // mode.
              Text(
                '모든 테마는 라이트 모드 기준으로 표시됩니다',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
              ),
              const SizedBox(height: 14),
              // 11 themes don't fit shorter screens — scroll instead of
              // overflowing.
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final name in AppThemeName.values)
                      _ThemeTile(
                        name: name,
                        selected: state.current == name,
                        onTap: () => context.read<AppThemeState>().setTheme(name),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThemeTile extends StatelessWidget {
  final AppThemeName name;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeTile({required this.name, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = previewAccent(name);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? accent.withValues(alpha: 0.07) : theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accent : theme.dividerColor,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              // Swatch: the theme's background as a disc with its accent as
              // the center dot — background + point color at a glance.
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: previewBackground(name),
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.dividerColor),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.label,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      name.description,
                      style: theme.textTheme.bodySmall?.copyWith(fontSize: 11.5),
                    ),
                  ],
                ),
              ),
              if (selected)
                Icon(Icons.check_circle, color: accent, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
