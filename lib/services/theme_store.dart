import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_theme.dart';

class ThemeStore {
  static const _key = 'app_theme_name';

  Future<AppThemeName> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    return AppThemeName.values.firstWhere(
      (t) => t.name == raw,
      orElse: () => AppThemeName.neutral,
    );
  }

  Future<void> save(AppThemeName name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, name.name);
  }
}
