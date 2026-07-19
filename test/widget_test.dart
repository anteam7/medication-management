import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:habit_streak/main.dart';
import 'package:habit_streak/models/app_theme_state.dart';
import 'package:habit_streak/models/medication_state.dart';
import 'package:habit_streak/services/medication_store.dart';
import 'package:habit_streak/services/theme_store.dart';

void main() {
  testWidgets('Medication list shows empty state on first launch',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = MedicationState(MedicationStore());
    await state.load();
    final themeState = AppThemeState(ThemeStore());
    await themeState.load();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: state),
          ChangeNotifierProvider.value(value: themeState),
        ],
        child: const HabitStreakApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('아직 등록된 약이 없어요'), findsOneWidget);
  });
}
