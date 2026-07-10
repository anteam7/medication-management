/// When relative to a meal a medication should be taken. Null/unspecified
/// means it doesn't matter.
enum MealTiming { beforeMeal, afterMeal }

extension MealTimingLabel on MealTiming {
  String get label => switch (this) {
        MealTiming.beforeMeal => '식전',
        MealTiming.afterMeal => '식후',
      };
}
