import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDark = true;
  int _colorIndex = 0;
  int _bgIndex = 0;

  static const List<Color> accentColors = [
    Color(0xFF7B68EE), // Bleu-violet
    Color(0xFF00BCD4), // Cyan
    Color(0xFFFF7043), // Orange chaud
    Color(0xFF66BB6A), // Vert
    Color(0xFFFFCA28), // Jaune doré
    Color(0xFFEC407A), // Rose
    Color(0xFF9575CD), // Violet
    Color(0xFF26C6DA), // Turquoise
  ];

  static const List<Map<String, dynamic>> backgroundColors = [
    {'color': Color(0xFF0A0E21), 'label': 'Nuit'},
    {'color': Color(0xFF121212), 'label': 'Noir'},
    {'color': Color(0xFF1C1C2E), 'label': 'Ardoise'},
    {'color': Color(0xFF1A0F2E), 'label': 'Violet'},
    {'color': Color(0xFF0F1E17), 'label': 'Foret'},
    {'color': Color(0xFF1E1114), 'label': 'Bordeaux'},
    {'color': Color(0xFF0E1A2B), 'label': 'Ocean'},
    {'color': Color(0xFF1E1B0F), 'label': 'Ambre'},
  ];

  bool get isDark => _isDark;
  int get colorIndex => _colorIndex;
  int get bgIndex => _bgIndex;
  Color get primaryColor => accentColors[_colorIndex];
  Color get backgroundColor =>
      _isDark ? (backgroundColors[_bgIndex]['color'] as Color) : const Color(0xFFF5F5FA);

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
        cardColor: bgColor.withValues(alpha: 0.8),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFE8E8F0)),
          bodyMedium: TextStyle(color: Color(0xFFD0D0DC)),
          bodySmall: TextStyle(color: Color(0xFFB0B0C0)),
          titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: Color(0xFFF0F0FF), fontWeight: FontWeight.w600),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: bgColor,
          foregroundColor: Colors.white,
          elevation: 0,
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        dialogTheme: DialogTheme(
          backgroundColor: Color.lerp(bgColor, Colors.white, 0.08)!,
          titleTextStyle: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          contentTextStyle: const TextStyle(color: Color(0xFFCCCCDD), fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.07),
          labelStyle: const TextStyle(color: Color(0xFF9999AA)),
          hintStyle: const TextStyle(color: Color(0xFF666680)),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primary, width: 2)),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: bgColor,
          selectedItemColor: primary,
          unselectedItemColor: const Color(0xFF666680),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: Color.lerp(bgColor, Colors.white, 0.15),
          contentTextStyle: const TextStyle(color: Colors.white),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return primary;
            return Colors.grey;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return primary.withValues(alpha: 0.3);
            return Colors.white.withValues(alpha: 0.1);
          }),
        ),
      );
    } else {
      // ─── MODE CLAIR COMPLET ───
      return ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: primary,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF5F5FA),
        canvasColor: Colors.white,
        cardColor: Colors.white,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF1A1A2E)),
          bodyMedium: TextStyle(color: Color(0xFF2E2E42)),
          bodySmall: TextStyle(color: Color(0xFF5A5A72)),
          titleLarge: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: Color(0xFF2E2E42), fontWeight: FontWeight.w600),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Color(0xFF1A1A2E),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(color: Color(0xFF1A1A2E), fontSize: 18, fontWeight: FontWeight.w700),
        ),
        dialogTheme: DialogTheme(
          backgroundColor: Colors.white,
          titleTextStyle: const TextStyle(color: Color(0xFF1A1A2E), fontSize: 18, fontWeight: FontWeight.bold),
          contentTextStyle: const TextStyle(color: Color(0xFF5A5A72), fontSize: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: BorderSide(color: primary.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF0F0F8),
          labelStyle: const TextStyle(color: Color(0xFF8888AA)),
          hintStyle: const TextStyle(color: Color(0xFFAAAABB)),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primary, width: 2)),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: primary,
          unselectedItemColor: const Color(0xFF999999),
        ),
        cardTheme: CardTheme(
          color: Colors.white,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return primary;
            return Colors.grey[400];
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return primary.withValues(alpha: 0.3);
            return Colors.grey.withValues(alpha: 0.2);
          }),
        ),
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
