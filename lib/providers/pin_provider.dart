import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/parent_profile.dart';

class PinProvider extends ChangeNotifier {
  String? _hashedPin;
  bool _isParentMode = false;

  // Plus de timeout : une fois en mode parent, on y reste jusqu'à verrouillage
  // manuel ou fermeture de l'app.
  // (sécurité conservée : au démarrage de l'app, toujours en mode enfant)

  // Anti-brute force
  int _failedAttempts = 0;
  DateTime? _lockoutUntil;
  static const _maxAttempts = 3;
  static const _lockoutDuration = Duration(minutes: 2);

  // Profil parent actuellement connecté (pour afficher son nom + photo)
  ParentProfile? _currentParentProfile;

  bool get isPinSet     => _hashedPin != null && _hashedPin!.isNotEmpty;
  bool get isParentMode => _isParentMode;
  ParentProfile? get currentParentProfile => _currentParentProfile;
  String get currentParentName => _currentParentProfile?.name ?? 'Parent';

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

    // ⚠️ Sécurité : au démémarrage, TOUJOURS en mode enfant.
    // Le mode parent n'est JAMAIS restauré depuis prefs.
    _isParentMode = false;
    _failedAttempts = 0;
    _lockoutUntil = null;
    _currentParentProfile = null;

    await prefs.remove('is_parent_mode');

    notifyListeners();
  }

  void refreshActivity() {
    // Plus de timeout : méthode gardée pour compatibilité (no-op).
  }

  /// Vérifie si on peut faire une action parent.
  /// Plus de timeout : si on est en mode parent, on y reste.
  bool canPerformParentAction() {
    if (!isPinSet)      return true;
    if (!_isParentMode) return false;
    refreshActivity();
    return true;
  }

  Future<void> setPin(String rawPin) async {
    if (rawPin.isEmpty) return;
    _hashedPin    = _hashPin(rawPin);
    _isParentMode = true;
    _failedAttempts = 0;
    _lockoutUntil = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('parent_pin_hashed', _hashedPin!);
    await prefs.remove('parent_pin');
    notifyListeners();
  }

  Future<void> removePin() async {
    _hashedPin    = null;
    _isParentMode = false;
    _failedAttempts = 0;
    _lockoutUntil = null;
    _currentParentProfile = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('parent_pin_hashed');
    await prefs.remove('parent_pin');
    await prefs.remove('is_parent_mode');
    notifyListeners();
  }

  /// Vérifie le PIN. Retourne true si correct, false sinon.
  /// Gère le blocage anti-brute-force.
  bool verifyPin(String rawInput) {
    if (isLockedOut) return false;
    if (_hashedPin == null) return false;

    final ok = _hashPin(rawInput) == _hashedPin;
    if (ok) {
      _isParentMode = true;
      _failedAttempts = 0;
      _lockoutUntil = null;
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

  /// Active le mode parent avec un profil parent spécifique (papa, maman, etc.)
  void unlockParentModeWithProfile(ParentProfile profile) {
    _isParentMode = true;
    _currentParentProfile = profile;
    _failedAttempts = 0;
    _lockoutUntil = null;
    notifyListeners();
  }

  void unlockParentMode() {
    _isParentMode = true;
    notifyListeners();
  }

  void lockParentMode() {
    _isParentMode = false;
    _currentParentProfile = null;
    notifyListeners();
  }

  void enterChildMode() {
    if (!isPinSet) return;
    _isParentMode = false;
    _currentParentProfile = null;
    notifyListeners();
  }
}
