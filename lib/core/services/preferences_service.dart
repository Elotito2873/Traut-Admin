import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const _themeKey = 'theme_mode';
  static const _sidebarKey = 'sidebar_expanded';
  static const _tableSizeKey = 'table_page_size';

  Future<ThemeMode> loadThemeMode() async {
    final value = (await SharedPreferences.getInstance()).getString(_themeKey);
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> saveThemeMode(ThemeMode mode) async {
    await (await SharedPreferences.getInstance()).setString(
      _themeKey,
      mode.name,
    );
  }

  Future<bool> loadSidebarExpanded() async =>
      (await SharedPreferences.getInstance()).getBool(_sidebarKey) ?? true;

  Future<void> saveSidebarExpanded(bool value) async {
    await (await SharedPreferences.getInstance()).setBool(_sidebarKey, value);
  }

  Future<int> loadTablePageSize() async =>
      (await SharedPreferences.getInstance()).getInt(_tableSizeKey) ?? 25;

  Future<void> saveTablePageSize(int value) async {
    await (await SharedPreferences.getInstance()).setInt(_tableSizeKey, value);
  }
}
