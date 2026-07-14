import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/medication_state.dart';
import 'screens/medication_list_screen.dart';
import 'services/medication_store.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.instance.init();

  final medicationState = MedicationState(MedicationStore());
  await medicationState.load();

  runApp(
    ChangeNotifierProvider.value(
      value: medicationState,
      child: const HabitStreakApp(),
    ),
  );
}

class HabitStreakApp extends StatelessWidget {
  const HabitStreakApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '복약 관리',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const MedicationListScreen(),
    );
  }
}
