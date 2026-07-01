// lib/services/voice_service.dart
//
// Service de synthèse vocale (TTS) pour SKS Family.
// Permet de faire "parler" l'app avec une voix joyeuse et enthousiaste.
//
// Utilisation simple :
//   await VoiceService.say('SKS Tribunal !');           // voix joyeuse normale
//   await VoiceService.celebrate('Félicitations Adam !'); // voix très joyeuse
//
// ⚠️ Sur web : la voix dépend du navigateur (parfois limité). Sur Android, voix
// native du système. Si pas de moteur TTS disponible, c'est silencieux (sans erreur).

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _available = false;

  /// Initialise le moteur TTS. À appeler au démarrage (main.dart).
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      // Configuration français
      await _tts.setLanguage('fr-FR');

      // Ton JOYEUX par défaut : pitch plus aigu + rythme légèrement plus rapide
      await _tts.setPitch(1.3);      // 1.0 = normal, 1.3 = joyeux/aigu
      await _tts.setSpeechRate(0.5); // 0.5 = un peu plus vif (Android: 0..1)

      // Volume max
      await _tts.setVolume(1.0);

      final result = await _tts.isLanguageAvailable('fr-FR');
      _available = result == true || result.toString() == 'true' || result == 1;

      // Sur Android, on force une voix française si dispo
      if (!kIsWeb && Platform.isAndroid) {
        final voices = await _tts.getVoices;
        if (voices is List) {
          // Cherche une voix FR de préférence féminine (plus douce pour une app famille)
          for (final v in voices) {
            if (v is String && v.toLowerCase().contains('fr') &&
                (v.toLowerCase().contains('female') ||
                 v.toLowerCase().contains('femme'))) {
              await _tts.setVoice({'name': v, 'locale': 'fr-FR'});
              break;
            }
          }
        }
      }

      if (kDebugMode) {
        debugPrint('VoiceService: TTS initialisé (disponible: $_available)');
      }
    } catch (e) {
      _available = false;
      if (kDebugMode) debugPrint('VoiceService init error: $e');
    }
  }

  /// Dit un texte avec la voix joyeuse par défaut.
  /// Ne fait rien si le TTS n'est pas disponible (silencieux, sans erreur).
  Future<void> say(String text) async {
    if (!_initialized) await init();
    if (!_available) return;
    try {
      await _tts.setPitch(1.3); // joyeux
      await _tts.speak(text);
    } catch (e) {
      if (kDebugMode) debugPrint('VoiceService.say error: $e');
    }
  }

  /// Dit un texte avec une voix ENTHOUSIASTE (encore plus joyeux + fort).
  /// Idéal pour les félicitations, victoires, annonces spéciales.
  Future<void> celebrate(String text) async {
    if (!_initialized) await init();
    if (!_available) return;
    try {
      await _tts.setPitch(1.6);  // très aigu = excité
      await _tts.setVolume(1.0); // fort
      await _tts.speak(text);
      // Reset au pitch normal après
      await _tts.setPitch(1.3);
    } catch (e) {
      if (kDebugMode) debugPrint('VoiceService.celebrate error: $e');
    }
  }

  /// Voix de JUGE (homme, très grave, autoritaire).
  /// Idéal pour le Tribunal.
  Future<void> sayAsJudge(String text) async {
    if (!_initialized) await init();
    if (!_available) return;
    try {
      await _tts.setPitch(0.6);  // très grave = voix d'homme
      await _tts.setSpeechRate(0.4); // lent et posé
      await _tts.setVolume(1.0);
      await _tts.speak(text);
      await _tts.setPitch(1.3); // reset
      await _tts.setSpeechRate(0.5);
    } catch (e) {
      if (kDebugMode) debugPrint('VoiceService.sayAsJudge error: $e');
    }
  }

  /// Voix d'ENFANT qui crie (très aigu, vif).
  /// Idéal pour les pénalités/immunités ("Oh là là là là !").
  Future<void> sayAsChild(String text) async {
    if (!_initialized) await init();
    if (!_available) return;
    try {
      await _tts.setPitch(1.9);  // très aigu = enfant
      await _tts.setSpeechRate(0.6); // vif
      await _tts.setVolume(1.0);
      await _tts.speak(text);
      await _tts.setPitch(1.3); // reset
      await _tts.setSpeechRate(0.5);
    } catch (e) {
      if (kDebugMode) debugPrint('VoiceService.sayAsChild error: $e');
    }
  }

  /// Coupe la voix en cours (si besoin).
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// True si la synthèse vocale est disponible sur cet appareil.
  bool get isAvailable => _available;
}
