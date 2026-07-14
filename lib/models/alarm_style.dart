/// How a medication's alarm notifies the user. Backed by two distinct
/// Android notification channels (see notification_service.dart) since a
/// channel's sound/vibration is fixed the first time it's created.
enum AlarmStyle { vibration, gentleSound }

extension AlarmStyleLabel on AlarmStyle {
  String get label => switch (this) {
        AlarmStyle.vibration => '진동',
        AlarmStyle.gentleSound => '잔잔한 소리',
      };
}
