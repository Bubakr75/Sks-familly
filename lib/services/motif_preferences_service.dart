// lib/services/motif_preferences_service.dart
//
// Gère les favoris et compteurs d'utilisation des motifs Bonus/Pénalité.
// Utilise SharedPreferences. Les favoris sont séparés bonus/penalty.
// Une erreur de SharedPreferences ne doit jamais bloquer l'application.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class MotifPreferencesService {
  static const _favKeyBonus = 'point_motif_favorites_v1_bonus';
  static const _favKeyPenalty = 'point_motif_favorites_v1_penalty';
  static const _usageKeyBonus = 'point_motif_usage_v1_bonus';
  static const _usageKeyPenalty = 'point_motif_usage_v1_penalty';

  /// Retourne la clé appropriée selon isBonus.
  static String _favKey(bool isBonus) =>
      isBonus ? _favKeyBonus : _favKeyPenalty;
  static String _usageKey(bool isBonus) =>
      isBonus ? _usageKeyBonus : _usageKeyPenalty;

  /// Charge les IDs de favoris.
  static Future<Set<String>> loadFavorites(bool isBonus) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_favKey(isBonus));
      if (raw == null) return {};
      final list = jsonDecode(raw) as List;
      return list.cast<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  /// Charge les compteurs d'utilisation (motifId → count).
  static Future<Map<String, int>> loadUsage(bool isBonus) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_usageKey(isBonus));
      if (raw == null) return {};
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return map.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  /// Ajoute ou retire un favori. Retourne le nouvel état des favoris.
  static Future<Set<String>> toggleFavorite(
      bool isBonus, String motifId) async {
    try {
      final favorites = await loadFavorites(isBonus);
      if (favorites.contains(motifId)) {
        favorites.remove(motifId);
      } else {
        favorites.add(motifId);
      }
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_favKey(isBonus), jsonEncode(favorites.toList()));
      return favorites;
    } catch (_) {
      return {};
    }
  }

  /// Incrémente le compteur d'utilisation après un addPoints réussi.
  static Future<void> incrementUsage(bool isBonus, String motifId) async {
    try {
      final usage = await loadUsage(isBonus);
      usage[motifId] = (usage[motifId] ?? 0) + 1;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_usageKey(isBonus), jsonEncode(usage));
    } catch (_) {
      // Ne jamais bloquer l'application
    }
  }

  /// Trie les motifs selon : favoris → fréquents → ordre d'origine.
  /// La carte "Autre" (isOther) reste toujours à la fin.
  static List<T> sortMotifs<T>({
    required List<T> motifs,
    required String Function(T) getId,
    required bool Function(T) isOther,
    required Set<String> favorites,
    required Map<String, int> usage,
  }) {
    final other = motifs.where(isOther).toList();
    final regular = motifs.where((m) => !isOther(m)).toList();

    // Séparer favoris et non-favoris
    final favs = regular.where((m) => favorites.contains(getId(m))).toList();
    final nonFavs =
        regular.where((m) => !favorites.contains(getId(m))).toList();

    // Trier favoris par fréquence décroissante, puis ordre d'origine stable
    favs.sort((a, b) {
      final ua = usage[getId(a)] ?? 0;
      final ub = usage[getId(b)] ?? 0;
      return ub.compareTo(ua);
    });

    // Trier non-favoris par fréquence décroissante, puis ordre d'origine stable
    nonFavs.sort((a, b) {
      final ua = usage[getId(a)] ?? 0;
      final ub = usage[getId(b)] ?? 0;
      return ub.compareTo(ua);
    });

    return [...favs, ...nonFavs, ...other];
  }
}
