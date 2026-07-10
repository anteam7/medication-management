import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:habit_streak/main.dart';
import 'package:habit_streak/models/medication_state.dart';
import 'package:habit_streak/services/medication_store.dart';

void main() {
  testWidgets('Medication list shows empty state on first launch',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = MedicationState(MedicationStore());
    await state.load();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: state,
        child: const HabitStreakApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('등록된 약이 없습니다'), findsOneWidget);
  });
}
