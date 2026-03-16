import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDark = true;
  int _colorIndex = 0;
  int _bgIndex = 0;

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

  static const List<Map<String, dynamic>> backgroundColors = [
    {'color': Color(0xFF0A0E21), 'label': 'Nuit'},
    {'color': Color(0xFF000000), 'label': 'Noir'},
    {'color': Color(0xFF1A1A2E), 'label': 'Gris'},
    {'color': Color(0xFF1A0A2E), 'label': 'Violet'},
    {'color': Color(0xFF0A1E14), 'label': 'Forêt'},
    {'color': Color(0xFF1E0A0A), 'label': 'Rouge'},
    {'color': Color(0xFF0A1A2E), 'label': 'Océan'},
    {'color': Color(0xFF1E1A0A), 'label': 'Ambre'},
  ];

  bool get isDark => _isDark;
  int get colorIndex => _colorIndex;
  int get bgIndex => _bgIndex;
  Color get primaryColor => accentColors[_colorIndex];
  Color get backgroundColor => _isDark
      ? (backgroundColors[_bgIndex]['color'] as Color)
      : Colors.white;

  ThemeData get theme {
    final primary = accentColors[_colorIndex];
    final bgColor = backgroundColor;
    if (_isDark) {
      return ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: primary,
        useMaterial3: true,
        scaffoldBackgroundColor: bgColor,
        canvasColor: bgColor,
        cardColor: bgColor.withOpacity(0.8),
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
    _bgIndex = prefs.getInt('bg_index') ?? 0;
    if (_colorIndex >= accentColors.length) _colorIndex = 0;
    if (_bgIndex >= backgroundColors.length) _bgIndex = 0;
    notifyListeners();
  }

  Future<void> toggle() async {
    _isDark = !_isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark', _isDark);
    notifyListeners();
  }

  Future<void> setColorIndex(int index) async {
    if (index >= 0 && index < accentColors.length) {
      _colorIndex = index;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('color_index', index);
      notifyListeners();
    }
  }

  Future<void> setBgIndex(int index) async {
    if (index >= 0 && index < backgroundColors.length) {
      _bgIndex = index;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('bg_index', index);
      notifyListeners();
    }
  }
}
