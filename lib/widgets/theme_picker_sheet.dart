import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_theme.dart';
import '../models/app_theme_state.dart';

Future<void> showThemePickerSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _ThemePickerSheet(),
  );
}

class _ThemePickerSheet extends StatelessWidget {
  const _ThemePickerSheet();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppThemeState>();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('테마 선택', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              '화면 밝기(라이트/다크)는 기기 설정을 따라갑니다',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
            const SizedBox(height: 12),
            for (final name in AppThemeName.values)
              _ThemeTile(
                name: name,
                selected: state.current == name,
                onTap: () => context.read<AppThemeState>().setTheme(name),
              ),
          ],
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
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: previewBackground(name),
          shape: BoxShape.circle,
          border: Border.all(color: previewAccent(name), width: 2),
        ),
      ),
      title: Text(name.label),
      subtitle: Text(name.description, style: const TextStyle(fontSize: 11)),
      trailing: selected ? const Icon(Icons.check_circle, color: Colors.green) : null,
    );
  }
}
