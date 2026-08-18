import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted user preferences that drive the global theme.
class AppSettings {
  const AppSettings({
    required this.themeMode,
    required this.useDynamicColor,
  });

  final ThemeMode themeMode;
  final bool useDynamicColor;

  AppSettings copyWith({ThemeMode? themeMode, bool? useDynamicColor}) =>
      AppSettings(
        themeMode: themeMode ?? this.themeMode,
        useDynamicColor: useDynamicColor ?? this.useDynamicColor,
      );

  static const initial =
      AppSettings(themeMode: ThemeMode.system, useDynamicColor: true);
}

class AppSettingsController extends StateNotifier<AppSettings> {
  AppSettingsController(this._prefs)
      : super(_load(_prefs));

  final SharedPreferences _prefs;

  static const _kThemeMode = 'theme_mode';
  static const _kDynamicColor = 'dynamic_color';

  static AppSettings _load(SharedPreferences prefs) {
    final modeIndex = prefs.getInt(_kThemeMode) ?? ThemeMode.system.index;
    final mode = ThemeMode.values[modeIndex.clamp(0, ThemeMode.values.length - 1)];
    final useDynamic = prefs.getBool(_kDynamicColor) ?? true;
    return AppSettings(themeMode: mode, useDynamicColor: useDynamic);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _prefs.setInt(_kThemeMode, mode.index);
  }

  Future<void> setUseDynamicColor(bool enabled) async {
    state = state.copyWith(useDynamicColor: enabled);
    await _prefs.setBool(_kDynamicColor, enabled);
  }
}

final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) {
  return SharedPreferences.getInstance();
});

final appSettingsProvider =
    StateNotifierProvider<AppSettingsController, AppSettings>((ref) {
  final prefsAsync = ref.watch(sharedPreferencesProvider);
  final prefs = prefsAsync.maybeWhen(
    data: (prefs) => prefs,
    orElse: () => throw StateError('SharedPreferences not ready'),
  );
  return AppSettingsController(prefs);
});