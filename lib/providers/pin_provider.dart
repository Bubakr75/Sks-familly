import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinProvider extends ChangeNotifier {
  String? _hashedPin;
  bool _isParentMode = false;
  DateTime? _lastActivity;
  static const _timeout = Duration(minutes: 10);

  bool get isPinSet     => _hashedPin != null && _hashedPin!.isNotEmpty;
  bool get isParentMode => _isParentMode;

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

    _isParentMode = prefs.getBool('is_parent_mode') ?? false;
    if (_isParentMode) _lastActivity = DateTime.now();
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
      _saveMode();
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('parent_pin_hashed', _hashedPin!);
    await prefs.remove('parent_pin');
    await prefs.setBool('is_parent_mode', true);
    notifyListeners();
  }

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

  // ══ AJOUT : bascule explicitement en mode enfant ══
  void enterChildMode() {
    if (!isPinSet) return;
    _isParentMode = false;
    _lastActivity = null;
    _saveMode();
    notifyListeners();
  }

  Future<void> _saveMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_parent_mode', _isParentMode);
    } catch (_) {}
  }
}
