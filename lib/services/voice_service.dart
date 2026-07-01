// lib/services/voice_service.dart
//
// Service de voix pour SKS Family.
// Utilise en priorité de VRAIS fichiers audio (enregistrements personnalisés).
// Fallback sur TTS (synthèse vocale) si le fichier n'existe pas.
//
// Utilisation :
//   await VoiceService.say('tribunal');     // joue assets/sounds/tribunal.wav
//   await VoiceService.say('penalite');     // joue assets/sounds/penalite.wav
//   await VoiceService.sayTts('Bonjour');   // TTS classique

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:audioplayers/audioplayers.dart';

class VoiceService {
  static final VoiceService _instance = VoiceService._internal();
  factory VoiceService() => _instance;
  VoiceService._internal();

  final FlutterTts _tts = FlutterTts();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _initialized = false;
  bool _ttsAvailable = false;

  /// Initialise le moteur TTS (fallback). À appeler au démarrage.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    try {
      await _tts.setLanguage('fr-FR');
      await _tts.setPitch(1.3);
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      final result = await _tts.isLanguageAvailable('fr-FR');
      _ttsAvailable = result == true || result.toString() == 'true' || result == 1;
    } catch (_) {}
  }

  /// 🎙️ Joue un fichier audio personnalisé (assets/sounds/{name}.wav).
  /// Fallback TTS si le fichier n'existe pas.
  Future<void> say(String name) async {
    try {
      // Essayer le fichier audio réel en priorité
      await _audioPlayer.play(AssetSource('sounds/$name.wav'), volume: 1.0);
      if (kDebugMode) debugPrint('VoiceService: fichier audio joué → sounds/$name.wav');
    } catch (e) {
      if (kDebugMode) debugPrint('VoiceService audio error ($name): $e → fallback TTS');
      // Fallback TTS selon le nom
      switch (name) {
        case 'tribunal':
          await sayAsJudge('Tribunal SKS');
          break;
        case 'penalite':
          await sayAsChild('Pénalités ! Oh là là là là !');
          break;
        case 'immunite':
          await sayAsChild('Immunité ! Youpi !');
          break;
      }
    }
  }

  /// Dit un texte avec le TTS (fallback).
  Future<void> sayTts(String text) async {
    if (!_initialized) await init();
    if (!_ttsAvailable) return;
    try {
      await _tts.setPitch(1.3);
      await _tts.speak(text);
    } catch (_) {}
  }

  /// Voix de JUGE (TTS fallback pour le tribunal).
  Future<void> sayAsJudge(String text) async {
    if (!_initialized) await init();
    if (!_ttsAvailable) return;
    try {
      await _tts.setPitch(0.6);
      await _tts.setSpeechRate(0.4);
      await _tts.setVolume(1.0);
      await _tts.speak(text);
      await _tts.setPitch(1.3);
      await _tts.setSpeechRate(0.5);
    } catch (_) {}
  }

  /// Voix d'ENFANT (TTS fallback pour pénalités/immunités).
  Future<void> sayAsChild(String text) async {
    if (!_initialized) await init();
    if (!_ttsAvailable) return;
    try {
      await _tts.setPitch(1.9);
      await _tts.setSpeechRate(0.6);
      await _tts.setVolume(1.0);
      await _tts.speak(text);
      await _tts.setPitch(1.3);
      await _tts.setSpeechRate(0.5);
    } catch (_) {}
  }

  /// Coupe tout (audio + TTS).
  Future<void> stop() async {
    try { await _audioPlayer.stop(); } catch (_) {}
    try { await _tts.stop(); } catch (_) {}
  }

  bool get isAvailable => _ttsAvailable;
}

