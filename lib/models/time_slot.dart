enum TimeSlot { morning, lunch, evening }

extension TimeSlotLabel on TimeSlot {
  String get label => switch (this) {
        TimeSlot.morning => '아침',
        TimeSlot.lunch => '점심',
        TimeSlot.evening => '저녁',
      };
}
