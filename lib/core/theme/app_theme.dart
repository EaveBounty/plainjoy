import 'package:flutter/material.dart';

import 'app_tokens.dart';

class AppTheme {
  static ThemeData editorial() => _build(AppTokens.editorial);

  static ThemeData q() => _build(AppTokens.q);

  static ThemeData _build(AppTokens t) {
    final scheme = ColorScheme.fromSeed(
      seedColor: t.accent,
      brightness: Brightness.light,
    ).copyWith(
      primary: t.accent,
      onPrimary: t.accentInk,
      secondary: t.good,
      onSecondary: Colors.white,
      surface: t.surface,
      onSurface: t.ink,
      error: t.veryHigh,
      onError: Colors.white,
      outline: t.hairline,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: t.background,
      fontFamily: t.bodyFont,
      fontFamilyFallback: const ['Noto Sans CJK SC', 'Noto Sans SC', 'sans-serif'],
      splashFactory: t.isQ ? InkSparkle.splashFactory : InkRipple.splashFactory,
      extensions: [t],
    );

    TextStyle style({
      required double size,
      FontWeight weight = FontWeight.w400,
      double? height,
      double? letterSpacing,
      String? family,
      Color? color,
    }) {
      return TextStyle(
        fontSize: size,
        fontWeight: weight,
        height: height,
        letterSpacing: letterSpacing,
        fontFamily: family ?? t.bodyFont,
        fontFamilyFallback: const ['Noto Sans CJK SC', 'Noto Sans SC', 'sans-serif'],
        color: color ?? t.ink,
      );
    }

    final textTheme = TextTheme(
      displayLarge: style(size: 44, weight: FontWeight.w600, height: 1.1, family: t.titleFont),
      displayMedium: style(size: 36, weight: FontWeight.w600, height: 1.12, family: t.titleFont),
      headlineLarge: style(size: 28, weight: FontWeight.w600, height: 1.2, family: t.titleFont),
      headlineMedium: style(size: 24, weight: FontWeight.w600, height: 1.22, family: t.titleFont),
      headlineSmall: style(size: 20, weight: FontWeight.w600, height: 1.25, family: t.titleFont),
      titleLarge: style(size: 20, weight: FontWeight.w600, height: 1.3, family: t.titleFont),
      titleMedium: style(size: 16, weight: FontWeight.w600, height: 1.35),
      titleSmall: style(size: 14, weight: FontWeight.w600, height: 1.35),
      bodyLarge: style(size: 16, height: 1.55),
      bodyMedium: style(size: 14, height: 1.55),
      bodySmall: style(size: 12, height: 1.5, color: t.inkSecondary),
      labelLarge: style(size: 14, weight: FontWeight.w600, height: 1.2),
      labelMedium: style(size: 12, weight: FontWeight.w600, height: 1.2),
      labelSmall: style(size: 11, weight: FontWeight.w500, height: 1.2, color: t.inkTertiary),
    );

    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: t.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: t.ink, size: 22),
        titleTextStyle: textTheme.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusLg),
          side: BorderSide(color: t.hairline, width: t.borderWidth),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: t.hairline,
        thickness: t.borderWidth,
        space: 1,
      ),
      iconTheme: IconThemeData(color: t.ink, size: 22),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surfaceAlt,
        hintStyle: textTheme.bodyMedium?.copyWith(color: t.inkTertiary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.radiusMd),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.radiusMd),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(t.radiusMd),
          borderSide: BorderSide(color: t.accent, width: t.isQ ? 2 : 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.accentInk,
          elevation: 0,
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.isQ ? t.pillRadius : t.radiusMd),
            side: t.isQ ? BorderSide(color: t.ink, width: 1.5) : BorderSide.none,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.accentInk,
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.isQ ? t.pillRadius : t.radiusMd),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: t.ink,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusSm),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: t.ink,
          minimumSize: const Size(0, 48),
          side: BorderSide(color: t.hairline, width: t.borderWidth),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.isQ ? t.pillRadius : t.radiusMd),
          ),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.surface,
        selectedColor: t.accent,
        disabledColor: t.surfaceAlt,
        labelStyle: textTheme.labelMedium!,
        secondaryLabelStyle: textTheme.labelMedium!.copyWith(color: t.accentInk),
        side: BorderSide(color: t.hairline, width: t.borderWidth),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.isQ ? t.pillRadius : t.radiusSm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: t.isQ ? t.accent.withValues(alpha: 0.12) : Colors.transparent,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: t.inkSecondary, size: 22)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(t.isQ ? 28 : 16),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.ink,
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: t.background),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusMd),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: t.accent,
        linearTrackColor: t.surfaceAlt,
        circularTrackColor: t.surfaceAlt,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: t.accent,
        inactiveTrackColor: t.surfaceAlt,
        thumbColor: t.accent,
        overlayColor: t.accent.withValues(alpha: 0.12),
        trackHeight: 4,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.accentInk;
          return t.inkTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return t.accent;
          return t.surfaceAlt;
        }),
      ),
    );
  }
}
