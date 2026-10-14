import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_constants.dart';

/// Provider exposing [SharedPreferences] instance.
/// Overridden in [main] with the pre-initialized instance.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

/// Riverpod Notifier controlling the active application [ThemeMode] with persistence.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  SharedPreferences? _prefs;

  @override
  ThemeMode build() {
    _prefs = ref.watch(sharedPreferencesProvider);
    if (_prefs != null) {
      final storedValue = _prefs!.getString(AppConstants.themeModeStorageKey);
      return parseThemeMode(storedValue);
    }

    _initAsync();
    return ThemeMode.system;
  }

  Future<void> _initAsync() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final storedValue = _prefs?.getString(AppConstants.themeModeStorageKey);
      if (storedValue != null) {
        final mode = parseThemeMode(storedValue);
        if (mode != state) {
          state = mode;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ThemeModeNotifier] Error loading stored theme: $e');
      }
    }
  }

  /// Sets and persists the application theme mode.
  Future<void> setThemeMode(ThemeMode mode) async {
    if (state == mode) return;
    state = mode;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setString(
        AppConstants.themeModeStorageKey,
        themeModeToString(mode),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ThemeModeNotifier] Failed to persist theme mode: $e');
      }
    }
  }

  /// Toggles between light and dark modes.
  Future<void> toggleTheme() async {
    await setThemeMode(
      state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
    );
  }

  /// Switches to light mode.
  Future<void> setLight() => setThemeMode(ThemeMode.light);

  /// Switches to dark mode.
  Future<void> setDark() => setThemeMode(ThemeMode.dark);

  /// Switches to system default mode.
  Future<void> setSystem() => setThemeMode(ThemeMode.system);

  /// Helper to convert a string to [ThemeMode] safely.
  static ThemeMode parseThemeMode(String? value) {
    return switch (value?.toLowerCase().trim()) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'system' => ThemeMode.system,
      _ => ThemeMode.system,
    };
  }

  /// Helper to convert [ThemeMode] to string key.
  static String themeModeToString(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}

/// Global provider for the active [ThemeMode].
final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);
