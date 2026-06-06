import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class TvDetector {
  static bool? _isTV;

  static Future<bool> detect() async {
    if (_isTV != null) return _isTV!;
    try {
      const platform = MethodChannel('com.sks.family/device');
      _isTV = await platform.invokeMethod<bool>('isTV') ?? false;
      if (kDebugMode) debugPrint('TV detection via native: $_isTV');
    } catch (e) {
      if (kDebugMode) debugPrint('TV detection fallback: $e');
      _isTV = null;
    }
    return _isTV ?? false;
  }

  static bool get isTV => _isTV ?? false;

  static void detectFromContext(double shortestSide, double longestSide, {double devicePixelRatio = 1.0}) {
    if (_isTV != null) return;
    // TV = grand ecran + faible densite de pixels + ratio large
    final ratio = longestSide / shortestSide;
    final isTvScreen = shortestSide >= 600 && longestSide >= 960 && devicePixelRatio <= 1.5 && ratio < 2.0;
    _isTV = isTvScreen;
    if (kDebugMode) debugPrint('TV detection via screen: $_isTV (short=$shortestSide, long=$longestSide, dpr=$devicePixelRatio, ratio=$ratio)');
  }

  static void forceTV(bool value) => _isTV = value;
}



