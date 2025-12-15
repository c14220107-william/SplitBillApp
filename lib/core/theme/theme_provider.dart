import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends StateNotifier<ThemeMode> {
  static const _themeKey = 'theme_mode';

  ThemeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeString = prefs.getString(_themeKey);
      if (themeString != null) {
        state = ThemeMode.values.firstWhere(
          (e) => e.toString() == themeString,
          orElse: () => ThemeMode.system,
        );
      }
    } catch (e) {
      // Fallback to system if error
      print('Error loading theme: $e');
    }
  }

  Future<void> toggleTheme(bool isDark) async {
    try {
      state = isDark ? ThemeMode.dark : ThemeMode.light;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, state.toString());
    } catch (e) {
      print('Error saving theme: $e');
    }
  }
}

final themeModeProvider = StateNotifierProvider<ThemeNotifier, ThemeMode>((
  ref,
) {
  return ThemeNotifier();
});
