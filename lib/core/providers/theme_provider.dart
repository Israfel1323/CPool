import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeProvider() {
    _loadPreference();
  }

  bool _loaded = false;

  ThemeMode get themeMode => ThemeMode.light;
  bool get isDark => false;
  bool get isLoaded => _loaded;

  Future<void> _loadPreference() async {
    _loaded = true;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    notifyListeners();
  }
}
