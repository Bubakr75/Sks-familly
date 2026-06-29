import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/emerald_theme.dart';

class ThemeProvider extends ChangeNotifier {
  bool _isDark = true;
  int _colorIndex = 0;
  int _bgIndex = 4; // Forêt (émeraude) par défaut

  static const List<Color> accentColors = [
    EmeraldPalette.emerald,    // Émeraude (par défaut)
    Color(0xFF7B68EE),         // Violet
    Color(0xFF00BCD4),         // Cyan
    Color(0xFFFF7043),         // Orange
    Color(0xFFFFCA28),         // Jaune
    Color(0xFFEC407A),         // Rose
    Color(0xFF9575CD),         // Lavande
    Color(0xFF26C6DA),         // Turquoise
  ];

  static const List<Map<String, dynamic>> backgroundColors = [
    {'color': EmeraldPalette.background, 'label': 'Émeraude'},
    {'color': Color(0xFF0A0E21), 'label': 'Nuit'},
    {'color': Color(0xFF121212), 'label': 'Noir'},
    {'color': Color(0xFF1C1C2E), 'label': 'Ardoise'},
    {'color': Color(0xFF1A0F2E), 'label': 'Violet'},
    {'color': Color(0xFF0F1E17), 'label': 'Forêt'},
    {'color': Color(0xFF1E1114), 'label': 'Bordeaux'},
    {'color': Color(0xFF0E1A2B), 'label': 'Océan'},
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
        cardColor: EmeraldPalette.surface,
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: EmeraldPalette.textPrimary),
          bodyMedium: TextStyle(color: EmeraldPalette.textPrimary),
          bodySmall: TextStyle(color: EmeraldPalette.textSecondary),
          titleLarge: TextStyle(color: EmeraldPalette.textPrimary, fontWeight: FontWeight.bold),
          titleMedium: TextStyle(color: EmeraldPalette.textPrimary, fontWeight: FontWeight.w600),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: bgColor,
          foregroundColor: EmeraldPalette.textPrimary,
          elevation: 0,
          titleTextStyle: TextStyle(color: EmeraldPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: EmeraldPalette.surface,
          titleTextStyle: TextStyle(color: EmeraldPalette.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          contentTextStyle: TextStyle(color: EmeraldPalette.textSecondary, fontSize: 14),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: EmeraldPalette.surfaceLow,
          labelStyle: TextStyle(color: EmeraldPalette.textSecondary),
          hintStyle: TextStyle(color: EmeraldPalette.textMuted),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: EmeraldPalette.glassBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: EmeraldPalette.glassBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 2)),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: bgColor,
          selectedItemColor: primary,
          unselectedItemColor: EmeraldPalette.textMuted,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: EmeraldPalette.surfaceHigh,
          contentTextStyle: TextStyle(color: EmeraldPalette.textPrimary),
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
        dividerTheme: DividerThemeData(
          color: EmeraldPalette.glassBorder,
          thickness: 1,
        ),
        iconTheme: IconThemeData(color: EmeraldPalette.textPrimary),
      );
    } else {
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
        dialogTheme: DialogThemeData(
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1))),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.1))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primary, width: 2)),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: primary,
          unselectedItemColor: const Color(0xFF999999),
        ),
        cardTheme: CardThemeData(
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
