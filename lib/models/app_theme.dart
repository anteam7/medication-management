import 'package:flutter/material.dart';

/// Themes adapted from Meta's Astryx design system
/// (https://astryx.atmeta.com/docs/getting-started). Astryx is a web/React
/// component library, so it can't be imported into a Flutter app directly —
/// instead, each theme's published `theme.css` color tokens were used to
/// reproduce the same look as a Material 3 [ThemeData].
enum AppThemeName { neutral, butter, chocolate, matcha, gothic, stone, y2k }

extension AppThemeNameLabel on AppThemeName {
  String get label => switch (this) {
        AppThemeName.neutral => '뉴트럴',
        AppThemeName.butter => '버터',
        AppThemeName.chocolate => '초콜릿',
        AppThemeName.matcha => '말차',
        AppThemeName.gothic => '고딕',
        AppThemeName.stone => '스톤',
        AppThemeName.y2k => 'Y2K',
      };

  String get description => switch (this) {
        AppThemeName.neutral => '어디에나 무난한 흑백 톤',
        AppThemeName.butter => '따뜻한 크림색 + 파란 포인트',
        AppThemeName.chocolate => '진한 브라운 톤',
        AppThemeName.matcha => '차분한 녹차색',
        AppThemeName.gothic => '어둡고 시크한 톤',
        AppThemeName.stone => '차가운 회색조',
        AppThemeName.y2k => '레트로 페리윙클 블루',
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
};

const Map<AppThemeName, _Palette> _dark = {
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
    appBarTheme: AppBarTheme(
      backgroundColor: palette.background,
      foregroundColor: palette.textPrimary,
      elevation: 0,
    ),
  );
}

/// Light-mode background/accent, used for small swatch previews in the
/// theme picker regardless of the device's current brightness.
Color previewBackground(AppThemeName name) => _light[name]!.background;
Color previewAccent(AppThemeName name) => _light[name]!.accent;
