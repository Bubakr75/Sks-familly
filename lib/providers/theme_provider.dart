import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/emerald_theme.dart';
import '../config/app_themes.dart';

class ThemeProvider extends ChangeNotifier {
  // ─── Identité de thème (système principal) ───
  String _themeId = AppThemes.defaultId;

  // ─── Système hérité (toujours fonctionnel pour rétro-compat) ───
  bool _isDark = true;
  int _colorIndex = 0;
  int _bgIndex = 0;

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

  // ─── Getters ───
  String get themeId => _themeId;
  bool get isDark => activeTheme.isDark;
  int get colorIndex => _colorIndex;
  int get bgIndex => _bgIndex;

  /// Thème actif (source de vérité pour les couleurs).
  AppThemeData get activeTheme => AppThemes.byId(_themeId);

  Color get primaryColor => activeTheme.primary;

  Color get backgroundColor => activeTheme.background;

  ThemeData get theme => _buildThemeData(activeTheme);

  // ─── Construction du ThemeData à partir d'un AppThemeData ───
  ThemeData _buildThemeData(AppThemeData t) {
    final primary = t.primary;
    final bgColor = t.background;
    final surface = t.surface;

    if (t.isDark) {
      return ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: primary,
        useMaterial3: true,
        scaffoldBackgroundColor: bgColor,
        canvasColor: bgColor,
        cardColor: surface,
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: t.textPrimary),
          bodyMedium: TextStyle(color: t.textPrimary),
          bodySmall: TextStyle(color: t.textSecondary),
          titleLarge:
              TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold),
          titleMedium:
              TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: bgColor,
          foregroundColor: t.textPrimary,
          elevation: 0,
          titleTextStyle: TextStyle(
              color: t.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: surface,
          titleTextStyle: TextStyle(
              color: t.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold),
          contentTextStyle: TextStyle(color: t.textSecondary, fontSize: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: t.surfaceLow,
          labelStyle: TextStyle(color: t.textSecondary),
          hintStyle: TextStyle(color: t.textMuted),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.glassBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.glassBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primary, width: 2)),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: bgColor,
          selectedItemColor: primary,
          unselectedItemColor: t.textMuted,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: t.surfaceHigh,
          contentTextStyle: TextStyle(color: t.textPrimary),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          behavior: SnackBarBehavior.floating,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return primary;
            return Colors.grey;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected))
              return primary.withValues(alpha: 0.3);
            return Colors.white.withValues(alpha: 0.1);
          }),
        ),
        dividerTheme: DividerThemeData(
          color: t.glassBorder,
          thickness: 1,
        ),
        iconTheme: IconThemeData(color: t.textPrimary),
      );
    } else {
      return ThemeData(
        brightness: Brightness.light,
        colorSchemeSeed: primary,
        useMaterial3: true,
        scaffoldBackgroundColor: bgColor,
        canvasColor: surface,
        cardColor: surface,
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: t.textPrimary),
          bodyMedium: TextStyle(color: t.textPrimary),
          bodySmall: TextStyle(color: t.textSecondary),
          titleLarge:
              TextStyle(color: t.textPrimary, fontWeight: FontWeight.bold),
          titleMedium:
              TextStyle(color: t.textPrimary, fontWeight: FontWeight.w600),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: bgColor,
          foregroundColor: t.textPrimary,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
              color: t.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700),
        ),
        dialogTheme: DialogThemeData(
          backgroundColor: surface,
          titleTextStyle: TextStyle(
              color: t.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold),
          contentTextStyle: TextStyle(color: t.textSecondary, fontSize: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: BorderSide(color: primary.withValues(alpha: 0.4)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: t.surfaceLow,
          labelStyle: TextStyle(color: t.textSecondary),
          hintStyle: TextStyle(color: t.textMuted),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.glassBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: t.glassBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: primary, width: 2)),
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          backgroundColor: surface,
          selectedItemColor: primary,
          unselectedItemColor: t.textMuted,
        ),
        cardTheme: CardThemeData(
          color: surface,
          elevation: 2,
          shadowColor: Colors.black.withValues(alpha: 0.08),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return primary;
            return Colors.grey[400];
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected))
              return primary.withValues(alpha: 0.3);
            return Colors.grey.withValues(alpha: 0.2);
          }),
        ),
        dividerTheme: DividerThemeData(
          color: t.glassBorder,
          thickness: 1,
        ),
        iconTheme: IconThemeData(color: t.textPrimary),
      );
    }
  }

  // ─── Init ───
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _themeId = prefs.getString('theme_id') ?? AppThemes.defaultId;
    _isDark = prefs.getBool('is_dark') ?? true;
    _colorIndex = prefs.getInt('color_index') ?? 0;
    _bgIndex = prefs.getInt('bg_index') ?? 0;
    if (_colorIndex >= accentColors.length) _colorIndex = 0;
    if (_bgIndex >= backgroundColors.length) _bgIndex = 0;
    notifyListeners();
  }

  // ─── Sélecteur de thème (API principale) ───
  Future<void> setThemeId(String id) async {
    _themeId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_id', id);
    notifyListeners();
  }

  // ─── API héritée (rétro-compatibilité) ───
  Future<void> toggle() async {
    // En mode multi-thèmes : bascule entre emerald (sombre) et light (clair)
    if (_themeId == 'light') {
      await setThemeId('emerald');
    } else {
      await setThemeId('light');
    }
    _isDark = activeTheme.isDark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_dark', _isDark);
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
