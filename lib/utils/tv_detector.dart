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

  static void detectFromContext(double shortestSide, double longestSide) {
    if (_isTV != null) return;
    _isTV = shortestSide >= 540 && longestSide >= 960;
    if (kDebugMode) debugPrint('TV detection via screen: $_isTV (short=$shortestSide, long=$longestSide)');
  }

  static void forceTV(bool value) => _isTV = value;
}
