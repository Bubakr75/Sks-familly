import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinProvider extends ChangeNotifier {
  String? _hashedPin;        // ✅ On ne stocke plus le PIN en clair
  bool _isParentMode = false;
  DateTime? _lastActivity;
  static const _timeout = Duration(minutes: 10);

  // ─── Getters ────────────────────────────────────────────────
  bool get isPinSet     => _hashedPin != null && _hashedPin!.isNotEmpty;
  bool get isParentMode => _isParentMode;

  // ✅ SÉCURITÉ : on n'expose plus jamais le PIN brut
  // L'ancien getter `String? get pin` est supprimé volontairement.

  // ─── Hash ────────────────────────────────────────────────────
  String _hashPin(String rawPin) {
    final bytes  = utf8.encode(rawPin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ─── Init ────────────────────────────────────────────────────
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();

    // Migration : si un ancien PIN en clair existe, on le hashe et on le remigre
    final legacyPin = prefs.getString('parent_pin');
    final hashedPin = prefs.getString('parent_pin_hashed');

    if (hashedPin != null && hashedPin.isNotEmpty) {
      _hashedPin = hashedPin;
    } else if (legacyPin != null && legacyPin.isNotEmpty) {
      // Migration automatique depuis l'ancien stockage en clair
      _hashedPin = _hashPin(legacyPin);
      await prefs.setString('parent_pin_hashed', _hashedPin!);
      await prefs.remove('parent_pin'); // supprime l'ancien
    }

    _isParentMode = prefs.getBool('is_parent_mode') ?? false;
    if (_isParentMode) _lastActivity = DateTime.now();
    notifyListeners();
  }

  // ─── Activité ───────────────────────────────────────────────
  void refreshActivity() {
    _lastActivity = DateTime.now();
  }

  bool canPerformParentAction() {
    if (!isPinSet)      return true;  // pas de PIN → accès libre
    if (!_isParentMode) return false;
    if (_lastActivity == null) return false;
    if (DateTime.now().difference(_lastActivity!) > _timeout) {
      _isParentMode = false;
      _saveMode();
      notifyListeners();
      return false;
    }
    refreshActivity(); // ✅ renouvelle le timer à chaque action
    return true;
  }

  // ─── Définir le PIN ─────────────────────────────────────────
  Future<void> setPin(String rawPin) async {
    if (rawPin.isEmpty) return;
    _hashedPin    = _hashPin(rawPin);
    _isParentMode = true;
    _lastActivity = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('parent_pin_hashed', _hashedPin!);
    await prefs.remove('parent_pin'); // nettoie l'éventuel ancien
    await prefs.setBool('is_parent_mode', true);
    notifyListeners();
  }

  // ─── Supprimer le PIN ───────────────────────────────────────
  Future<void> removePin() async {
    _hashedPin    = null;
    _isParentMode = false;
    _lastActivity = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('parent_pin_hashed');
    await prefs.remove('parent_pin');
    await prefs.remove('is_parent_mode');
    notifyListeners();
  }

  // ─── Vérifier le PIN ────────────────────────────────────────
  bool verifyPin(String rawInput) {
    if (_hashedPin == null) return false;
    final ok = _hashPin(rawInput) == _hashedPin;
    if (ok) {
      _isParentMode = true;
      _lastActivity = DateTime.now();
      _saveMode();
      notifyListeners();
    }
    return ok;
  }

  // ─── Mode parent ────────────────────────────────────────────
  void unlockParentMode() {
    _isParentMode = true;
    _lastActivity = DateTime.now();
    _saveMode();
    notifyListeners();
  }

  void lockParentMode() {
    _isParentMode = false;
    _lastActivity = null;
    _saveMode();
    notifyListeners();
  }

  // ─── Sauvegarde du mode ─────────────────────────────────────
  Future<void> _saveMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_parent_mode', _isParentMode);
    } catch (_) {}
  }
}
