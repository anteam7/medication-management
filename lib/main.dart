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

  await NotificationService.instance.init();

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
      darkTheme: buildAppTheme(themeName, Brightness.dark),
      themeMode: ThemeMode.system,
      home: const MedicationListScreen(),
    );
  }
}
