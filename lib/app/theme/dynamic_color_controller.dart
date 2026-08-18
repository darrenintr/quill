import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';

import 'app_theme.dart';

/// Resolves the effective color scheme at app start, falling back to the
/// brand seed if dynamic-color is unavailable (iOS, older Android, desktop).
class DynamicColorController {
  const DynamicColorController();

  Future<ColorScheme> lightScheme() async {
    final core = await DynamicColorPlugin.getCorePalette();
    if (core != null) {
      return core.toColorScheme(brightness: Brightness.light);
    }
    return ThemeData.light().colorScheme;
  }

  Future<ColorScheme> darkScheme() async {
    final core = await DynamicColorPlugin.getCorePalette();
    if (core != null) {
      return core.toColorScheme(brightness: Brightness.dark);
    }
    return ThemeData.dark().colorScheme;
  }

  Color brandSeed() => AppTheme.brandSeed;
}