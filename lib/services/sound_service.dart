// lib/services/sound_service.dart
//
// 🔊 Service audio — feedback sonore pour les actions.
// Utilise HapticFeedback (vibrations) comme feedback tactile + sons système.
// Sur mobile : SystemSound.click + vibration.
// Sur web : vibration uniquement.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class SoundService {
  static bool _enabled = true;

  /// Active/désactive les sons (depuis les paramètres)
  static set enabled(bool v) => _enabled = v;
  static bool get enabled => _enabled;

  /// ✅ Bonus — vibration moyenne + clic
  static Future<void> playBonus() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
    await SystemSound.play(SystemSoundType.click);
  }

  /// ❌ Pénalité — vibration forte + clic
  static Future<void> playPenalty() async {
    if (!_enabled) return;
    await HapticFeedback.heavyImpact();
    await SystemSound.play(SystemSoundType.click);
  }

  /// 🛒 Achat boutique — double clic
  static Future<void> playPurchase() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
    await SystemSound.play(SystemSoundType.click);
    await Future.delayed(const Duration(milliseconds: 100));
    await SystemSound.play(SystemSoundType.click);
  }

  /// 🎡 Roue de la fortune — vibration légère
  static Future<void> playWheelTick() async {
    if (!_enabled) return;
    await HapticFeedback.selectionClick();
  }

  /// 🏆 Niveau supérieur — triple vibration
  static Future<void> playLevelUp() async {
    if (!_enabled) return;
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.mediumImpact();
    await Future.delayed(const Duration(milliseconds: 80));
    await HapticFeedback.heavyImpact();
  }

  /// 🎉 Jackpot — séquence de vibrations
  static Future<void> playJackpot() async {
    if (!_enabled) return;
    for (int i = 0; i < 4; i++) {
      await HapticFeedback.mediumImpact();
      await Future.delayed(const Duration(milliseconds: 60));
    }
    await HapticFeedback.heavyImpact();
  }
}
