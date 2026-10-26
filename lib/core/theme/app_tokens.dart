import 'package:flutter/material.dart';

import '../models/enums.dart';

@immutable
class PetStyle {
  final Color base;
  final Color secondary;
  final Color belly;
  final Color nose;
  final Color eye;
  final Color blush;
  final double headScale;
  final double bodyRoundness;
  final double eyeScale;
  final double outlineWidth;
  final double blushOpacity;
  final double earRoundness;

  const PetStyle({
    required this.base,
    required this.secondary,
    required this.belly,
    required this.nose,
    required this.eye,
    required this.blush,
    this.headScale = 1.0,
    this.bodyRoundness = 1.0,
    this.eyeScale = 1.0,
    this.outlineWidth = 1.5,
    this.blushOpacity = 0.0,
    this.earRoundness = 1.0,
  });

  static PetStyle forSpecies(PetSpecies species, {required bool q}) {
    final base = switch (species) {
      PetSpecies.calicoCat => const Color(0xFFF4E3D0),
      PetSpecies.tabbyCat => const Color(0xFFC9A27A),
      PetSpecies.orangeCat => const Color(0xFFE8A45C),
      PetSpecies.tuxedoCat => const Color(0xFF3B3B43),
      PetSpecies.shibaInu => const Color(0xFFD99A5B),
      PetSpecies.corgi => const Color(0xFFE0A45E),
      PetSpecies.tuxedoDog => const Color(0xFF8C6A4A),
    };
    final secondary = switch (species) {
      PetSpecies.calicoCat => const Color(0xFF4A3A32),
      PetSpecies.tabbyCat => const Color(0xFF6B4A32),
      PetSpecies.orangeCat => const Color(0xFFB86A2E),
      PetSpecies.tuxedoCat => const Color(0xFFF6F1E8),
      PetSpecies.shibaInu => const Color(0xFFF6E7D2),
      PetSpecies.corgi => const Color(0xFFF7EAD8),
      PetSpecies.tuxedoDog => const Color(0xFF5A3E2A),
    };
    return PetStyle(
      base: base,
      secondary: secondary,
      belly: q ? const Color(0xFFFFFBF4) : const Color(0xFFF8F0E4),
      nose: const Color(0xFFC97B7B),
      eye: const Color(0xFF2A2320),
      blush: const Color(0xFFFF8F7A),
      headScale: q ? 1.18 : 1.0,
      bodyRoundness: q ? 1.25 : 1.0,
      eyeScale: q ? 1.25 : 1.0,
      outlineWidth: q ? 2.0 : 1.2,
      blushOpacity: q ? 0.55 : 0.18,
      earRoundness: q ? 1.35 : 1.0,
    );
  }

  PetStyle copyWith({
    Color? base,
    Color? secondary,
    Color? belly,
    Color? nose,
    Color? eye,
    Color? blush,
    double? headScale,
    double? bodyRoundness,
    double? eyeScale,
    double? outlineWidth,
    double? blushOpacity,
    double? earRoundness,
  }) {
    return PetStyle(
      base: base ?? this.base,
      secondary: secondary ?? this.secondary,
      belly: belly ?? this.belly,
      nose: nose ?? this.nose,
      eye: eye ?? this.eye,
      blush: blush ?? this.blush,
      headScale: headScale ?? this.headScale,
      bodyRoundness: bodyRoundness ?? this.bodyRoundness,
      eyeScale: eyeScale ?? this.eyeScale,
      outlineWidth: outlineWidth ?? this.outlineWidth,
      blushOpacity: blushOpacity ?? this.blushOpacity,
      earRoundness: earRoundness ?? this.earRoundness,
    );
  }

  static PetStyle lerp(PetStyle a, PetStyle b, double t) {
    return PetStyle(
      base: Color.lerp(a.base, b.base, t)!,
      secondary: Color.lerp(a.secondary, b.secondary, t)!,
      belly: Color.lerp(a.belly, b.belly, t)!,
      nose: Color.lerp(a.nose, b.nose, t)!,
      eye: Color.lerp(a.eye, b.eye, t)!,
      blush: Color.lerp(a.blush, b.blush, t)!,
      headScale: _lerpDouble(a.headScale, b.headScale, t),
      bodyRoundness: _lerpDouble(a.bodyRoundness, b.bodyRoundness, t),
      eyeScale: _lerpDouble(a.eyeScale, b.eyeScale, t),
      outlineWidth: _lerpDouble(a.outlineWidth, b.outlineWidth, t),
      blushOpacity: _lerpDouble(a.blushOpacity, b.blushOpacity, t),
      earRoundness: _lerpDouble(a.earRoundness, b.earRoundness, t),
    );
  }
}

double _lerpDouble(double a, double b, double t) => a + (b - a) * t;

@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  final ThemeVariant variant;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color ink;
  final Color inkSecondary;
  final Color inkTertiary;
  final Color hairline;
  final Color accent;
  final Color accentInk;
  final Color good;
  final Color low;
  final Color high;
  final Color veryHigh;
  final Color unknown;
  final Color warning;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double pillRadius;
  final double borderWidth;
  final Offset hardShadowOffset;
  final Color hardShadowColor;
  final String titleFont;
  final String bodyFont;
  final String numberFont;
  final double chartLineWidth;
  final Color chartGridColor;
  final double motionMs;
  final Curve motionCurve;
  final PetStyle petStyle;

  const AppTokens({
    required this.variant,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.inkSecondary,
    required this.inkTertiary,
    required this.hairline,
    required this.accent,
    required this.accentInk,
    required this.good,
    required this.low,
    required this.high,
    required this.veryHigh,
    required this.unknown,
    required this.warning,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.pillRadius,
    required this.borderWidth,
    required this.hardShadowOffset,
    required this.hardShadowColor,
    required this.titleFont,
    required this.bodyFont,
    required this.numberFont,
    required this.chartLineWidth,
    required this.chartGridColor,
    required this.motionMs,
    required this.motionCurve,
    required this.petStyle,
  });

  bool get isQ => variant == ThemeVariant.q;

  static const editorial = AppTokens(
    variant: ThemeVariant.editorial,
    background: Color(0xFFFAF8F5),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF3EFE8),
    ink: Color(0xFF17191C),
    inkSecondary: Color(0xFF55524C),
    inkTertiary: Color(0xFF8C877E),
    hairline: Color(0xFFE5E0D8),
    accent: Color(0xFF17191C),
    accentInk: Color(0xFFFFFFFF),
    good: Color(0xFF2C7A57),
    low: Color(0xFF3E6FA8),
    high: Color(0xFFA85A1B),
    veryHigh: Color(0xFF7E2A2A),
    unknown: Color(0xFF8C877E),
    warning: Color(0xFFA85A1B),
    radiusSm: 4,
    radiusMd: 8,
    radiusLg: 12,
    pillRadius: 999,
    borderWidth: 1,
    hardShadowOffset: Offset.zero,
    hardShadowColor: Color(0x00000000),
    titleFont: 'Noto Serif SC',
    bodyFont: 'Noto Sans SC',
    numberFont: 'Noto Sans SC',
    chartLineWidth: 1.5,
    chartGridColor: Color(0x668C877E),
    motionMs: 320,
    motionCurve: Curves.easeOutCubic,
    petStyle: PetStyle(
      base: Color(0xFFF4E3D0),
      secondary: Color(0xFF4A3A32),
      belly: Color(0xFFF8F0E4),
      nose: Color(0xFFC97B7B),
      eye: Color(0xFF2A2320),
      blush: Color(0xFFFF8F7A),
      headScale: 1.0,
      bodyRoundness: 1.0,
      eyeScale: 1.0,
      outlineWidth: 1.2,
      blushOpacity: 0.18,
    ),
  );

  static const q = AppTokens(
    variant: ThemeVariant.q,
    background: Color(0xFFFFF9F2),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFFFF1E4),
    ink: Color(0xFF3A2E2A),
    inkSecondary: Color(0xFF6B5A52),
    inkTertiary: Color(0xFF9A867C),
    hairline: Color(0xFFEADCCF),
    accent: Color(0xFF6E56CF),
    accentInk: Color(0xFFFFFFFF),
    good: Color(0xFF2C7A57),
    low: Color(0xFF3E6FA8),
    high: Color(0xFFA85A1B),
    veryHigh: Color(0xFF7E2A2A),
    unknown: Color(0xFF8C877E),
    warning: Color(0xFFA85A1B),
    radiusSm: 8,
    radiusMd: 16,
    radiusLg: 24,
    pillRadius: 999,
    borderWidth: 1.5,
    hardShadowOffset: Offset(0, 3),
    hardShadowColor: Color(0xFF3A2E2A),
    titleFont: 'Noto Sans SC',
    bodyFont: 'Noto Sans SC',
    numberFont: 'Noto Sans SC',
    chartLineWidth: 3,
    chartGridColor: Color(0x559A867C),
    motionMs: 180,
    motionCurve: Curves.easeOutBack,
    petStyle: PetStyle(
      base: Color(0xFFF4E3D0),
      secondary: Color(0xFF4A3A32),
      belly: Color(0xFFFFFBF4),
      nose: Color(0xFFC97B7B),
      eye: Color(0xFF2A2320),
      blush: Color(0xFFFF8F7A),
      headScale: 1.18,
      bodyRoundness: 1.25,
      eyeScale: 1.3,
      outlineWidth: 2.0,
      blushOpacity: 0.55,
      earRoundness: 1.35,
    ),
  );

  @override
  AppTokens copyWith({
    ThemeVariant? variant,
    Color? background,
    Color? surface,
    Color? surfaceAlt,
    Color? ink,
    Color? inkSecondary,
    Color? inkTertiary,
    Color? hairline,
    Color? accent,
    Color? accentInk,
    Color? good,
    Color? low,
    Color? high,
    Color? veryHigh,
    Color? unknown,
    Color? warning,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? pillRadius,
    double? borderWidth,
    Offset? hardShadowOffset,
    Color? hardShadowColor,
    String? titleFont,
    String? bodyFont,
    String? numberFont,
    double? chartLineWidth,
    Color? chartGridColor,
    double? motionMs,
    Curve? motionCurve,
    PetStyle? petStyle,
  }) {
    return AppTokens(
      variant: variant ?? this.variant,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      ink: ink ?? this.ink,
      inkSecondary: inkSecondary ?? this.inkSecondary,
      inkTertiary: inkTertiary ?? this.inkTertiary,
      hairline: hairline ?? this.hairline,
      accent: accent ?? this.accent,
      accentInk: accentInk ?? this.accentInk,
      good: good ?? this.good,
      low: low ?? this.low,
      high: high ?? this.high,
      veryHigh: veryHigh ?? this.veryHigh,
      unknown: unknown ?? this.unknown,
      warning: warning ?? this.warning,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      pillRadius: pillRadius ?? this.pillRadius,
      borderWidth: borderWidth ?? this.borderWidth,
      hardShadowOffset: hardShadowOffset ?? this.hardShadowOffset,
      hardShadowColor: hardShadowColor ?? this.hardShadowColor,
      titleFont: titleFont ?? this.titleFont,
      bodyFont: bodyFont ?? this.bodyFont,
      numberFont: numberFont ?? this.numberFont,
      chartLineWidth: chartLineWidth ?? this.chartLineWidth,
      chartGridColor: chartGridColor ?? this.chartGridColor,
      motionMs: motionMs ?? this.motionMs,
      motionCurve: motionCurve ?? this.motionCurve,
      petStyle: petStyle ?? this.petStyle,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      variant: t < 0.5 ? variant : other.variant,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceAlt: Color.lerp(surfaceAlt, other.surfaceAlt, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      inkSecondary: Color.lerp(inkSecondary, other.inkSecondary, t)!,
      inkTertiary: Color.lerp(inkTertiary, other.inkTertiary, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      good: Color.lerp(good, other.good, t)!,
      low: Color.lerp(low, other.low, t)!,
      high: Color.lerp(high, other.high, t)!,
      veryHigh: Color.lerp(veryHigh, other.veryHigh, t)!,
      unknown: Color.lerp(unknown, other.unknown, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      radiusSm: _lerpDouble(radiusSm, other.radiusSm, t),
      radiusMd: _lerpDouble(radiusMd, other.radiusMd, t),
      radiusLg: _lerpDouble(radiusLg, other.radiusLg, t),
      pillRadius: _lerpDouble(pillRadius, other.pillRadius, t),
      borderWidth: _lerpDouble(borderWidth, other.borderWidth, t),
      hardShadowOffset: Offset.lerp(hardShadowOffset, other.hardShadowOffset, t)!,
      hardShadowColor: Color.lerp(hardShadowColor, other.hardShadowColor, t)!,
      titleFont: t < 0.5 ? titleFont : other.titleFont,
      bodyFont: t < 0.5 ? bodyFont : other.bodyFont,
      numberFont: t < 0.5 ? numberFont : other.numberFont,
      chartLineWidth: _lerpDouble(chartLineWidth, other.chartLineWidth, t),
      chartGridColor: Color.lerp(chartGridColor, other.chartGridColor, t)!,
      motionMs: _lerpDouble(motionMs, other.motionMs, t),
      motionCurve: t < 0.5 ? motionCurve : other.motionCurve,
      petStyle: PetStyle.lerp(petStyle, other.petStyle, t),
    );
  }
}

extension AppTokensX on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>() ?? AppTokens.editorial;
  bool get isQ => tokens.isQ;
}
