import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDark = true;
  int _colorIndex = 0;

  static const List<Color> accentColors = [
    Color(0xFF6C63FF),
    Color(0xFF00E5FF),
    Color(0xFFFF6E40),
    Color(0xFF00E676),
    Color(0xFFFFD740),
    Color(0xFFFF4081),
    Color(0xFF7C4DFF),
    Color(0xFF18FFFF),
  ];

  bool get isDark => _isDark;
  int get colorIndex => _colorIndex;
  Color get primaryColor => accentColors[_colorIndex];

  ThemeData get theme {
    final primary = accentColors[_colorIndex];
    if (_isDark) {
      return ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: primary,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A0E21),
      );
    } else {
      return ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: primary,
        useMaterial3: true,
      );
    }
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isDark = prefs.getBool('is_dark') ?? true;
    _colorIndex = prefs.getInt('color_index') ?? 0;
    if (_colorIndex >= accentColors.length) _colorIndex = 0;
    notifyListeners();
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark', _isDark);
    notifyListeners();
  }

  Future<void> setColorIndex(int index) async {
    _colorIndex = index;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('color_index', index);
    notifyListeners();
  }
}
