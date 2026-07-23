/// How a medication's alarm notifies the user. Backed by a distinct Android
/// notification channel per style (see notification_service.dart) since a
/// channel's sound/vibration is fixed the first time it's created.
enum AlarmStyle { vibration, gentleSound, bell, upbeat, alert, voiceGeorge, voiceElara }

extension AlarmStyleLabel on AlarmStyle {
  String get label => switch (this) {
        AlarmStyle.vibration => '진동',
        AlarmStyle.gentleSound => '잔잔한 소리',
        AlarmStyle.bell => '벨 소리',
        AlarmStyle.upbeat => '경쾌한 소리',
        AlarmStyle.alert => '또렷한 알림음',
        AlarmStyle.voiceGeorge => '남성 목소리1',
        AlarmStyle.voiceElara => '여성 목소리1',
      };
}
