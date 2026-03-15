import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinProvider extends ChangeNotifier {
  String? _pin;
  bool _isParentMode = false;

  bool get isPinSet => _pin != null && _pin!.isNotEmpty;
  bool get isParentMode => _isParentMode;
  String? get pin => _pin;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _pin = prefs.getString('parent_pin');
    _isParentMode = prefs.getBool('is_parent_mode') ?? false;
    notifyListeners();
  }

  Future<void> setPin(String pin) async {
    _pin = pin;
    _isParentMode = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('parent_pin', pin);
    await prefs.setBool('is_parent_mode', true);
    notifyListeners();
  }

  Future<void> removePin() async {
    _pin = null;
    _isParentMode = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('parent_pin');
    await prefs.remove('is_parent_mode');
    notifyListeners();
  }

  bool verifyPin(String input) {
    if (_pin == null) return false;
    final ok = input == _pin;
    if (ok) {
      _isParentMode = true;
      _saveMode();
      notifyListeners();
    }
    return ok;
  }

  void unlockParentMode() {
    _isParentMode = true;
    _saveMode();
    notifyListeners();
  }

  void lockParentMode() {
    _isParentMode = false;
    _saveMode();
    notifyListeners();
  }

  Future<void> _saveMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_parent_mode', _isParentMode);
  }
}
