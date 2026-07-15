import 'package:flutter/material.dart';

import '../services/theme_store.dart';
import 'app_theme.dart';

class AppThemeState extends ChangeNotifier {
  final ThemeStore _store;
  AppThemeState(this._store);

  AppThemeName current = AppThemeName.neutral;

  Future<void> load() async {
    current = await _store.load();
    notifyListeners();
  }

  Future<void> setTheme(AppThemeName name) async {
    if (current == name) return;
    current = name;
    notifyListeners();
    await _store.save(name);
  }
}
