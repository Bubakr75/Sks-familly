// lib/config/app_themes.dart
//
// Système de thèmes SKS Family.
// Trois identités visuelles sélectionnables dans les réglages :
//   - 'emerald' : Émeraude Premium (vert nuit + or + crème) — par défaut
//   - 'aurora'  : Aurora Glass (violet / cyan / rose, glassmorphism + néons)
//   - 'light'   : Clair & Épuré (blanc / crème, ombres douces, accent vert)
//
// Chaque thème est décrit par un [AppThemeData] contenant palette, dégradés
// et métadonnées d'affichage (nom, sous-titre, swatches pour l'aperçu).
// Le ThemeData Material est construit par ThemeProvider à partir de l'actif.

import 'package:flutter/material.dart';
import 'emerald_theme.dart';

// ─────────────────────────────────────────────────────────────
//  Modèle de thème
// ─────────────────────────────────────────────────────────────

class AppThemeData {
  /// Identifiant stable, persisté dans SharedPreferences.
  final String id;

  /// Nom affiché dans le sélecteur.
  final String name;

  /// Sous-titre descriptif.
  final String subtitle;

  /// True si le thème est sombre (fond foncé, texte clair).
  final bool isDark;

  /// Couleurs de fond / surfaces.
  final Color background;
  final Color surface;
  final Color surfaceHigh;
  final Color surfaceLow;

  /// Accents principaux.
  final Color primary;
  final Color primaryLight;
  final Color gold;

  /// Textes.
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;

  /// États.
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  /// Bordures / verre.
  final Color glassBorder;

  /// Dégradés réutilisables.
  final LinearGradient primaryGradient;

  /// 4 couleurs pour l'aperçu (swatches) dans le sélecteur.
  final List<Color> swatches;

  /// Emoji représentatif.
  final String emoji;

  const AppThemeData({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surfaceHigh,
    required this.surfaceLow,
    required this.primary,
    required this.primaryLight,
    required this.gold,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.glassBorder,
    required this.primaryGradient,
    required this.swatches,
    required this.emoji,
  });

  static const AppThemeData empty = AppThemeData(
    id: '',
    name: '',
    subtitle: '',
    isDark: true,
    background: Colors.black,
    surface: Colors.black,
    surfaceHigh: Colors.black,
    surfaceLow: Colors.black,
    primary: Colors.white,
    primaryLight: Colors.white,
    gold: Colors.white,
    textPrimary: Colors.white,
    textSecondary: Colors.white,
    textMuted: Colors.white,
    success: Colors.green,
    warning: Colors.orange,
    error: Colors.red,
    info: Colors.blue,
    glassBorder: Colors.white,
    primaryGradient: LinearGradient(colors: [Colors.white, Colors.white]),
    swatches: [],
    emoji: '',
  );
}

// ─────────────────────────────────────────────────────────────
//  Registre des thèmes
// ─────────────────────────────────────────────────────────────

class AppThemes {
  AppThemes._();

  static const String defaultId = 'emerald';

  static const List<AppThemeData> all = [
    emerald,
    aurora,
    light,
  ];

  /// Thème Émeraude Premium (réutilise la palette existante).
  static const AppThemeData emerald = AppThemeData(
    id: 'emerald',
    name: 'Émeraude Premium',
    subtitle: 'Vert nuit · Or · Crème',
    isDark: true,
    background: EmeraldPalette.background,
    surface: EmeraldPalette.surface,
    surfaceHigh: EmeraldPalette.surfaceHigh,
    surfaceLow: EmeraldPalette.surfaceLow,
    primary: EmeraldPalette.emerald,
    primaryLight: EmeraldPalette.emeraldLight,
    gold: EmeraldPalette.gold,
    textPrimary: EmeraldPalette.textPrimary,
    textSecondary: EmeraldPalette.textSecondary,
    textMuted: EmeraldPalette.textMuted,
    success: EmeraldPalette.success,
    warning: EmeraldPalette.warning,
    error: EmeraldPalette.error,
    info: EmeraldPalette.info,
    // glassBorder = blanc à 8% (équivalent const de EmeraldPalette.glassBorder)
    glassBorder: Color(0x14FFFFFF),
    primaryGradient: EmeraldPalette.emeraldGradient,
    swatches: [
      Color(0xFF051410), // fond
      Color(0xFF00E676), // émeraude
      Color(0xFFD4AF37), // or
      Color(0xFFF5F1E8), // crème
    ],
    emoji: '🌿',
  );

  /// Thème Aurora Glass — néons vifs sur fond violet sombre.
  static const AppThemeData aurora = AppThemeData(
    id: 'aurora',
    name: 'Aurora Glass',
    subtitle: 'Violet · Cyan · Rose néon',
    isDark: true,
    background: Color(0xFF0A0A1F),
    surface: Color(0xFF141432),
    surfaceHigh: Color(0xFF1E1E44),
    surfaceLow: Color(0xFF0F0F28),
    primary: Color(0xFF7C4DFF), // violet
    primaryLight: Color(0xFFB388FF),
    gold: Color(0xFFEC4899), // rose magenta comme accent secondaire
    textPrimary: Color(0xFFF3F0FF),
    textSecondary: Color(0xFFA59FD5),
    textMuted: Color(0xFF6B6890),
    success: Color(0xFF00E5FF), // cyan
    warning: Color(0xFFFFD740),
    error: Color(0xFFFF5277),
    info: Color(0xFF00E5FF),
    glassBorder: Color(0x33FFFFFF),
    primaryGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
    ),
    swatches: [
      Color(0xFF0A0A1F), // fond
      Color(0xFF7C4DFF), // violet
      Color(0xFF00E5FF), // cyan
      Color(0xFFEC4899), // rose
    ],
    emoji: '🌌',
  );

  /// Thème Clair & Épuré — fond clair, ombres douces, accent vert.
  static const AppThemeData light = AppThemeData(
    id: 'light',
    name: 'Clair & Épuré',
    subtitle: 'Blanc · Crème · Vert frais',
    isDark: false,
    background: Color(0xFFF7F8FA),
    surface: Color(0xFFFFFFFF),
    surfaceHigh: Color(0xFFF1F3F7),
    surfaceLow: Color(0xFFECEFF5),
    primary: Color(0xFF00B879), // vert frais
    primaryLight: Color(0xFF4ECDC4),
    gold: Color(0xFFF4B400),
    textPrimary: Color(0xFF1A1D29),
    textSecondary: Color(0xFF5A6072),
    textMuted: Color(0xFF9AA0B0),
    success: Color(0xFF00B879),
    warning: Color(0xFFF59E0B),
    error: Color(0xFFEF4444),
    info: Color(0xFF3B82F6),
    glassBorder: Color(0xFFE2E6EF),
    primaryGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF00B879), Color(0xFF00897B)],
    ),
    swatches: [
      Color(0xFFF7F8FA), // fond
      Color(0xFFFFFFFF), // carte
      Color(0xFF00B879), // vert
      Color(0xFF1A1D29), // texte
    ],
    emoji: '☀️',
  );

  /// Récupère un thème par son id (fallback = emerald).
  static AppThemeData byId(String id) {
    for (final t in all) {
      if (t.id == id) return t;
    }
    return emerald;
  }
}

// ─────────────────────────────────────────────────────────────
//  Extension pratique pour accéder au thème actif depuis le BuildContext
// ─────────────────────────────────────────────────────────────

/// Accès rapide au [AppThemeData] actif depuis n'importe quel widget.
/// Usage : `final t = context.appTheme;` puis `t.surface`, `t.primary`...
AppThemeData appThemeOf(BuildContext context) {
  final brigh = Theme.of(context).brightness;
  // Le ThemeProvider expose l'active via un InheritedWidget implicite
  // (Consumer<ThemeProvider>). Pour un accès sans Consumer, on se base
  // sur la luminosité Material : dark => palettes sombres par défaut.
  // NOTE : les composants qui ont besoin du thème EXACT doivent utiliser
  // context.read<ThemeProvider>().activeTheme ou un Consumer.
  return brigh == Brightness.dark ? AppThemes.emerald : AppThemes.light;
}
