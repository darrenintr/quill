import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';

import 'typography.dart';

/// Centralized Material 3 theme builder for Quill.
///
/// We use [FlexColorScheme] (8.x) for opinionated sub-theming — it ships a
/// polished set of M3 component defaults (cards, chips, navigation, etc.)
/// that we layer our typography and dynamic-color preferences on top of.
class AppTheme {
  AppTheme._();

  /// Default brand seed — a warm ink-violet. Substituted on Android 12+
  /// devices with dynamic-color when [useDynamicColor] is enabled.
  static const Color brandSeed = Color(0xFF6750A4);

  /// Builds a light theme. The optional [seed] overrides the brand seed; the
  /// caller typically passes a dynamic-color-derived [ColorScheme.primary].
  static ThemeData light({Color? seed}) {
    final scheme = FlexColorScheme.light(
      colors: FlexSchemeColor.from(
        primary: seed ?? brandSeed,
        brightness: Brightness.light,
      ),
      appBarStyle: FlexAppBarStyle.scaffoldBackground,
      appBarElevation: 0,
      appBarBackground: Colors.transparent,
      tooltipsMatchBackground: true,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 7,
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      subThemesData: const FlexSubThemesData(
        defaultRadius: 12,
        elevatedButtonRadius: 20,
        filledButtonRadius: 20,
        navigationBarHeight: 80,
        chipRadius: 8,
        cardRadius: 16,
        dialogRadius: 28,
        bottomSheetRadius: 28,
        fabRadius: 16,
        snackBarRadius: 12,
      ),
    ).toTheme;
    return _applyTypography(scheme, Brightness.light);
  }

  /// Builds a dark theme.
  static ThemeData dark({Color? seed}) {
    final scheme = FlexColorScheme.dark(
      colors: FlexSchemeColor.from(
        primary: seed ?? brandSeed,
        brightness: Brightness.dark,
      ),
      appBarStyle: FlexAppBarStyle.scaffoldBackground,
      appBarElevation: 0,
      appBarBackground: Colors.transparent,
      tooltipsMatchBackground: true,
      surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
      blendLevel: 13,
      visualDensity: FlexColorScheme.comfortablePlatformDensity,
      subThemesData: const FlexSubThemesData(
        defaultRadius: 12,
        elevatedButtonRadius: 20,
        filledButtonRadius: 20,
        navigationBarHeight: 80,
        chipRadius: 8,
        cardRadius: 16,
        dialogRadius: 28,
        bottomSheetRadius: 28,
        fabRadius: 16,
        snackBarRadius: 12,
      ),
    ).toTheme;
    return _applyTypography(scheme, Brightness.dark);
  }

  static ThemeData _applyTypography(ThemeData base, Brightness brightness) {
    final textTheme = AppTypography.buildTextTheme(brightness);
    return base.copyWith(
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: base.iconTheme.copyWith(color: base.colorScheme.onSurface),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}