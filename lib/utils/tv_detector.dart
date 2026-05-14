import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class TvDetector {
  static bool? _isTV;

  /// Detecte si l'app tourne sur une TV Android.
  /// Verifie la taille d'ecran et la presence du D-pad.
  static Future<bool> detect() async {
    if (_isTV != null) return _isTV!;
    try {
      const platform = MethodChannel('com.sks.family/device');
      _isTV = await platform.invokeMethod<bool>('isTV') ?? false;
    } catch (_) {
      // Fallback : pas de channel natif, on utilise la taille ecran
      _isTV = false;
    }
    return _isTV!;
  }

  /// Methode synchrone apres init, ou detection par taille ecran
  static bool get isTV => _isTV ?? false;

  /// Detecte via la taille de l'ecran (appelee dans le premier build)
  static void detectFromContext(double shortestSide, double longestSide) {
    if (_isTV != null) return;
    // TV = ecran large (>= 960dp shortest) OU ratio tres large
    // et pas de touch comme input principal
    _isTV = shortestSide >= 540 && longestSide >= 960;
  }

  /// Force le mode TV (pour debug)
  static void forceTV(bool value) => _isTV = value;
}
