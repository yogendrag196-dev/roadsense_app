import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kThemePreferenceKey = 'roadsense_theme_mode';

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.dark) {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_kThemePreferenceKey);
      if (savedTheme != null) {
        if (savedTheme == 'light') {
          state = ThemeMode.light;
        } else if (savedTheme == 'dark') {
          state = ThemeMode.dark;
        } else if (savedTheme == 'system') {
          state = ThemeMode.system;
        }
      }
    } catch (_) {
      // Default to dark
      state = ThemeMode.dark;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;
    try {
      final prefs = await SharedPreferences.getInstance();
      String value = 'dark';
      if (mode == ThemeMode.light) {
        value = 'light';
      } else if (mode == ThemeMode.system) {
        value = 'system';
      }
      await prefs.setString(_kThemePreferenceKey, value);
    } catch (_) {}
  }

  Future<void> toggleTheme() async {
    if (state == ThemeMode.dark) {
      await setThemeMode(ThemeMode.light);
    } else {
      await setThemeMode(ThemeMode.dark);
    }
  }
}

final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
