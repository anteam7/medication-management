import 'package:flutter/material.dart';

/// Themes adapted from Meta's Astryx design system
/// (https://astryx.atmeta.com/docs/getting-started). Astryx is a web/React
/// component library, so it can't be imported into a Flutter app directly —
/// instead, each theme's published `theme.css` color tokens were used to
/// reproduce the same look as a Material 3 [ThemeData].
///
/// The first three (whiteClinic/softPastel/monoCoral) are a separate,
/// brighter/cleaner set proposed directly for this app and are listed first
/// so they show up ahead of the Astryx set in the theme picker.
enum AppThemeName {
  whiteClinic,
  softPastel,
  monoCoral,
  neutral,
  butter,
  chocolate,
  matcha,
  gothic,
  stone,
  y2k,
  classic,
}

extension AppThemeNameLabel on AppThemeName {
  String get label => switch (this) {
        AppThemeName.whiteClinic => '화이트 클리닉',
        AppThemeName.softPastel => '소프트 파스텔',
        AppThemeName.monoCoral => '모던 모노',
        AppThemeName.neutral => '뉴트럴',
        AppThemeName.butter => '버터',
        AppThemeName.chocolate => '초콜릿',
        AppThemeName.matcha => '말차',
        AppThemeName.gothic => '고딕',
        AppThemeName.stone => '스톤',
        AppThemeName.y2k => 'Y2K',
        AppThemeName.classic => '클래식',
      };

  String get description => switch (this) {
        AppThemeName.whiteClinic => '순백 배경 + 세이지 그린 포인트',
        AppThemeName.softPastel => '라벤더 배경 + 시간대별 파스텔 색',
        AppThemeName.monoCoral => '무채색 + 코랄 포인트 하나',
        AppThemeName.neutral => '어디에나 무난한 흑백 톤',
        AppThemeName.butter => '따뜻한 크림색 + 파란 포인트',
        AppThemeName.chocolate => '진한 브라운 톤',
        AppThemeName.matcha => '차분한 녹차색',
        AppThemeName.gothic => '어둡고 시크한 톤',
        AppThemeName.stone => '차가운 회색조',
        AppThemeName.y2k => '레트로 페리윙클 블루',
        AppThemeName.classic => '아이보리 + 버건디, 전통적인 느낌',
      };
}

class _Palette {
  final Color textPrimary;
  final Color textSecondary;
  final Color accent;
  final Color background;
  final Color surface;
  final Color card;
  final Color error;
  final Color border;

  const _Palette({
    required this.textPrimary,
    required this.textSecondary,
    required this.accent,
    required this.background,
    required this.surface,
    required this.card,
    required this.error,
    required this.border,
  });
}

const Map<AppThemeName, _Palette> _light = {
  AppThemeName.whiteClinic: _Palette(
    textPrimary: Color(0xFF1C2321),
    textSecondary: Color(0xFF6E7A77),
    accent: Color(0xFF2F6F62),
    background: Color(0xFFFFFFFF),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    error: Color(0xFFB3413F),
    border: Color(0xFFE6E9E8),
  ),
  AppThemeName.softPastel: _Palette(
    textPrimary: Color(0xFF262A3D),
    textSecondary: Color(0xFF767CA0),
    accent: Color(0xFF6C63FF),
    background: Color(0xFFEEF1FB),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    error: Color(0xFFE2515B),
    border: Color(0xFFE3E6F7),
  ),
  AppThemeName.monoCoral: _Palette(
    textPrimary: Color(0xFF141414),
    textSecondary: Color(0xFF7A7A78),
    accent: Color(0xFFFF4B3E),
    background: Color(0xFFF7F7F6),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    error: Color(0xFFB23A2E),
    border: Color(0xFFE5E4E1),
  ),
  AppThemeName.neutral: _Palette(
    textPrimary: Color(0xFF171717),
    textSecondary: Color(0xFF737373),
    accent: Color(0xFF262626),
    background: Color(0xFFF1F1F1),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    error: Color(0xFFA50C25),
    border: Color(0xFFEBEBEB),
  ),
  AppThemeName.butter: _Palette(
    textPrimary: Color(0xFF1D1C11),
    textSecondary: Color(0xFF605F52),
    accent: Color(0xFF225BFF),
    background: Color(0xFFFDFBE4),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    error: Color(0xFF771210),
    border: Color(0xFFE5E3D4),
  ),
  AppThemeName.chocolate: _Palette(
    textPrimary: Color(0xFF4A3520),
    textSecondary: Color(0xFFB88859),
    accent: Color(0xFF8C5927),
    background: Color(0xFFFFFCF7),
    surface: Color(0xFFFFFCF7),
    card: Color(0xFFEDE4D4),
    error: Color(0xFFFD0000),
    border: Color(0xFFC4AC95),
  ),
  AppThemeName.matcha: _Palette(
    textPrimary: Color(0xFF3E481D),
    textSecondary: Color(0xFF707E46),
    accent: Color(0xFF3E481D),
    background: Color(0xFFF0F0E0),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    error: Color(0xFFFD0000),
    border: Color(0xFFDCE3CE),
  ),
  AppThemeName.gothic: _Palette(
    textPrimary: Color(0xFF101314),
    textSecondary: Color(0xFF4B545C),
    accent: Color(0xFF101314),
    background: Color(0xFFF0F3F5),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFE8F1F6),
    error: Color(0xFF7A3F3B),
    border: Color(0xFFD8DEE2),
  ),
  AppThemeName.stone: _Palette(
    textPrimary: Color(0xFF25252A),
    textSecondary: Color(0xFF83838A),
    accent: Color(0xFF25252A),
    background: Color(0xFFF3F3F5),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    error: Color(0xFF58413E),
    border: Color(0xFFE2E2E8),
  ),
  AppThemeName.y2k: _Palette(
    textPrimary: Color(0xFF2D241B),
    textSecondary: Color(0xFF675D52),
    accent: Color(0xFF2D241B),
    background: Color(0xFFCCCFFA),
    surface: Color(0xFFFFFFFF),
    card: Color(0xFFFFFFFF),
    error: Color(0xFFB3413F),
    border: Color(0xFF2F292E),
  ),
  AppThemeName.classic: _Palette(
    textPrimary: Color(0xFF2B2118),
    textSecondary: Color(0xFF6B5D4F),
    accent: Color(0xFF7A2E2E),
    background: Color(0xFFF7F3EA),
    surface: Color(0xFFFDFBF6),
    card: Color(0xFFFDFBF6),
    error: Color(0xFFA83232),
    border: Color(0xFFE3DCC9),
  ),
};

const Map<AppThemeName, _Palette> _dark = {
  AppThemeName.whiteClinic: _Palette(
    textPrimary: Color(0xFFE7EFEC),
    textSecondary: Color(0xFF93A29D),
    accent: Color(0xFF7FBBA6),
    background: Color(0xFF14201C),
    surface: Color(0xFF1B2521),
    card: Color(0xFF202B26),
    error: Color(0xFFE59D9A),
    border: Color(0x1AE7EFEC),
  ),
  AppThemeName.softPastel: _Palette(
    textPrimary: Color(0xFFE7E8FA),
    textSecondary: Color(0xFF9DA1CE),
    accent: Color(0xFF9B94FF),
    background: Color(0xFF14152A),
    surface: Color(0xFF1B1D33),
    card: Color(0xFF21233D),
    error: Color(0xFFFF9AA2),
    border: Color(0x1AE7E8FA),
  ),
  AppThemeName.monoCoral: _Palette(
    textPrimary: Color(0xFFF2F2F0),
    textSecondary: Color(0xFFA8A7A3),
    accent: Color(0xFFFF6B5E),
    background: Color(0xFF121212),
    surface: Color(0xFF181818),
    card: Color(0xFF1E1E1E),
    error: Color(0xFFFF9187),
    border: Color(0x1AF2F2F0),
  ),
  AppThemeName.neutral: _Palette(
    textPrimary: Color(0xFFFAFAFA),
    textSecondary: Color(0xFFA3A3A3),
    accent: Color(0xFFEBEBEB),
    background: Color(0xFF1B1B1B),
    surface: Color(0xFF262626),
    card: Color(0xFF1B1B1B),
    error: Color(0xFFFFC6C1),
    border: Color(0x1AFFFFFF),
  ),
  AppThemeName.butter: _Palette(
    textPrimary: Color(0xFFF3F2E2),
    textSecondary: Color(0xFFADAC9E),
    accent: Color(0xFFFDEE8C),
    background: Color(0xFF261A13),
    surface: Color(0xFF2E2117),
    card: Color(0xFF3A2A1F),
    error: Color(0xFFFFB4A6),
    border: Color(0x1AF3F2E2),
  ),
  AppThemeName.chocolate: _Palette(
    textPrimary: Color(0xFFEDE4D4),
    textSecondary: Color(0xFFC4A882),
    accent: Color(0xFFD4A06A),
    background: Color(0xFF141010),
    surface: Color(0xFF1C1610),
    card: Color(0xFF2A2018),
    error: Color(0xFFFF5C5C),
    border: Color(0x1AEDE4D4),
  ),
  AppThemeName.matcha: _Palette(
    textPrimary: Color(0xFFC0CBA9),
    textSecondary: Color(0xFF94A468),
    accent: Color(0xFFC0CBA9),
    background: Color(0xFF12140E),
    surface: Color(0xFF1A1C14),
    card: Color(0xFF1E2016),
    error: Color(0xFFFF5C5C),
    border: Color(0x1AC0CBA9),
  ),
  AppThemeName.gothic: _Palette(
    textPrimary: Color(0xFFE8F1F6),
    textSecondary: Color(0xFF96A0AB),
    accent: Color(0xFFE8F1F6),
    background: Color(0xFF101314),
    surface: Color(0xFF101314),
    card: Color(0xFF1A1D20),
    error: Color(0xFFC6A6A2),
    border: Color(0x1AE8F1F6),
  ),
  AppThemeName.stone: _Palette(
    textPrimary: Color(0xFFF3F3F5),
    textSecondary: Color(0xFF9D9DA3),
    accent: Color(0xFFF3F3F5),
    background: Color(0xFF111015),
    surface: Color(0xFF1B1B1F),
    card: Color(0xFF242325),
    error: Color(0xFFDCC0BC),
    border: Color(0x1AF3F3F5),
  ),
  AppThemeName.y2k: _Palette(
    textPrimary: Color(0xFFEDEFFC),
    textSecondary: Color(0xFFA6ACD6),
    accent: Color(0xFFEDEFFC),
    background: Color(0xFF0E0F1A),
    surface: Color(0xFF16182B),
    card: Color(0xFF16182B),
    error: Color(0xFFFFC5C3),
    border: Color(0x1AEDEFFC),
  ),
  AppThemeName.classic: _Palette(
    textPrimary: Color(0xFFEDE6D6),
    textSecondary: Color(0xFFB8A98C),
    accent: Color(0xFFC08A4E),
    background: Color(0xFF1A1613),
    surface: Color(0xFF221D18),
    card: Color(0xFF2A241D),
    error: Color(0xFFE08585),
    border: Color(0x1AEDE6D6),
  ),
};

/// Builds a full Material 3 [ThemeData] for [name]/[brightness]. Astryx's
/// "accent" token is used to seed a complete, guaranteed-accessible Material
/// color scheme (Astryx doesn't publish the full set of container/tertiary
/// roles Material 3 needs), then the theme's actual background/surface/text
/// tokens are laid on top so each theme keeps its real look.
ThemeData buildAppTheme(AppThemeName name, Brightness brightness) {
  final palette = (brightness == Brightness.light ? _light : _dark)[name]!;

  final scheme = ColorScheme.fromSeed(
    seedColor: palette.accent,
    brightness: brightness,
  ).copyWith(
    surface: palette.surface,
    onSurface: palette.textPrimary,
    onSurfaceVariant: palette.textSecondary,
    error: palette.error,
    outline: palette.border,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: palette.background,
    cardColor: palette.card,
    dividerColor: palette.border,
    // A flat, bordered card and a touch of extra letter-spacing/whitespace
    // reads as calmer and more traditional than Material's default heavy
    // drop-shadow, tightly-packed look.
    visualDensity: VisualDensity.comfortable,
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      foregroundColor: palette.textPrimary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: palette.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    ),
    cardTheme: CardThemeData(
      color: palette.card,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: palette.border),
      ),
    ),
    dividerTheme: DividerThemeData(color: palette.border, thickness: 1, space: 1),
    textTheme: ThemeData(brightness: brightness).textTheme.apply(
      bodyColor: palette.textPrimary,
      displayColor: palette.textPrimary,
    ).copyWith(
      titleLarge: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
      titleMedium: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: 0.2),
    ),
  );
}

/// Light-mode background/accent, used for small swatch previews in the
/// theme picker regardless of the device's current brightness.
Color previewBackground(AppThemeName name) => _light[name]!.background;
Color previewAccent(AppThemeName name) => _light[name]!.accent;
