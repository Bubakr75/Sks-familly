import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinProvider extends ChangeNotifier {
  String? _hashedPin;
  bool _isParentMode = false;
  DateTime? _lastActivity;
  static const _timeout = Duration(minutes: 30); // 30 min avant verrouillage auto

  // Anti-brute force
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  static const _maxAttempts = 3;
  static const _lockoutDuration = Duration(minutes: 2);

  bool get isPinSet     => _hashedPin != null && _hashedPin!.isNotEmpty;
  bool get isParentMode => _isParentMode;

  /// True si le compte est temporairement bloqué (trop de tentatives échouées)
  bool get isLockedOut =>
      _lockoutUntil != null && DateTime.now().isBefore(_lockoutUntil!);

  /// Temps restant de blocage en secondes (0 si non bloqué)
  int get lockoutRemainingSeconds {
    if (!isLockedOut) return 0;
    return _lockoutUntil!.difference(DateTime.now()).inSeconds;
  }

  String _hashPin(String rawPin) {
    final bytes  = utf8.encode(rawPin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyPin = prefs.getString('parent_pin');
    final hashedPin = prefs.getString('parent_pin_hashed');

    if (hashedPin != null && hashedPin.isNotEmpty) {
      _hashedPin = hashedPin;
    } else if (legacyPin != null && legacyPin.isNotEmpty) {
      _hashedPin = _hashPin(legacyPin);
      await prefs.setString('parent_pin_hashed', _hashedPin!);
      await prefs.remove('parent_pin');
    }

    // ⚠️ CORRIGÉ : NE JAMAIS restaurer _isParentMode depuis prefs.
    // Au démarrage, on est TOUJOURS en mode enfant, même si l'app a été
    // fermée en mode parent. Sinon un enfant qui ouvre l'app serait
    // directement en mode parent sans taper le PIN.
    _isParentMode = false;
    _lastActivity = null;
    _failedAttempts = 0;
    _lockoutUntil = null;

    // Nettoyer l'ancienne valeur persistée (au cas où elle existerait)
    await prefs.remove('is_parent_mode');

    notifyListeners();
  }

  void refreshActivity() {
    _lastActivity = DateTime.now();
  }

  bool canPerformParentAction() {
    if (!isPinSet)      return true;
    if (!_isParentMode) return false;
    if (_lastActivity == null) return false;
    if (DateTime.now().difference(_lastActivity!) > _timeout) {
      _isParentMode = false;
      _lastActivity = null;
      notifyListeners();
      return false;
    }
    refreshActivity();
    return true;
  }

  Future<void> setPin(String rawPin) async {
    if (rawPin.isEmpty) return;
    _hashedPin    = _hashPin(rawPin);
    _isParentMode = true;
    _lastActivity = DateTime.now();
    _failedAttempts = 0;
    _lockoutUntil = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('parent_pin_hashed', _hashedPin!);
    await prefs.remove('parent_pin');
    // ⚠️ NE PAS sauvegarder is_parent_mode en prefs
    notifyListeners();
  }

  Future<void> removePin() async {
    _hashedPin    = null;
    _isParentMode = false;
    _lastActivity = null;
    _failedAttempts = 0;
    _lockoutUntil = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('parent_pin_hashed');
    await prefs.remove('parent_pin');
    await prefs.remove('is_parent_mode');
    notifyListeners();
  }

  /// Vérifie le PIN. Retourne true si correct, false sinon.
  /// Gère en interne le blocage anti-brute-force (3 essais → 2 min de blocage).
  /// Vérifier [isLockedOut] avant d'appeler pour savoir si le compte est bloqué.
  bool verifyPin(String rawInput) {
    if (isLockedOut) return false;
    if (_hashedPin == null) return false;

    final ok = _hashPin(rawInput) == _hashedPin;
    if (ok) {
      _isParentMode = true;
      _lastActivity = DateTime.now();
      _failedAttempts = 0;
      _lockoutUntil = null;
      // ⚠️ NE PAS sauvegarder is_parent_mode en prefs
      notifyListeners();
      return true;
    } else {
      _failedAttempts++;
      if (_failedAttempts >= _maxAttempts) {
        _lockoutUntil = DateTime.now().add(_lockoutDuration);
        _failedAttempts = 0;
      }
      notifyListeners();
      return false;
    }
  }

  void unlockParentMode() {
    _isParentMode = true;
    _lastActivity = DateTime.now();
    notifyListeners();
  }

  void lockParentMode() {
    _isParentMode = false;
    _lastActivity = null;
    notifyListeners();
  }

  void enterChildMode() {
    if (!isPinSet) return;
    _isParentMode = false;
    _lastActivity = null;
    notifyListeners();
  }
}
