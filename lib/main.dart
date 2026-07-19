import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/app_theme.dart';
import 'models/app_theme_state.dart';
import 'models/medication_state.dart';
import 'screens/medication_list_screen.dart';
import 'services/medication_store.dart';
import 'services/notification_service.dart';
import 'services/theme_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Alarms are important but not worth bricking the whole app over — if the
  // notification plugin fails to initialize (e.g. running on a desktop
  // platform it doesn't support, or a platform-channel hiccup), the app
  // should still start and let the user manage medications.
  try {
    await NotificationService.instance.init();
  } catch (e) {
    debugPrint('Notification init failed: $e');
  }

  final medicationState = MedicationState(MedicationStore());
  await medicationState.load();

  final themeState = AppThemeState(ThemeStore());
  await themeState.load();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: medicationState),
        ChangeNotifierProvider.value(value: themeState),
      ],
      child: const HabitStreakApp(),
    ),
  );
}

class HabitStreakApp extends StatelessWidget {
  const HabitStreakApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeName = context.watch<AppThemeState>().current;
    return MaterialApp(
      title: '복약 관리',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(themeName, Brightness.light),
      // Pinned to light regardless of the device's system setting — the
      // themes (especially the bright/clean set) are designed and shown to
      // the user as light-mode looks, and following system dark mode would
      // silently swap in the dark palette instead.
      themeMode: ThemeMode.light,
      home: const MedicationListScreen(),
    );
  }
}
