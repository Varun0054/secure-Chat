import 'package:flutter/material.dart';

class ThemeController with ChangeNotifier {
  static final ThemeController instance = ThemeController._internal();

  factory ThemeController() {
    return instance;
  }

  ThemeController._internal();

  ThemeMode _themeMode = ThemeMode.dark;
  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode => _themeMode == ThemeMode.dark;

  void toggleTheme(bool isDark) {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
  }
}
