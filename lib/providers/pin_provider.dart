import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinProvider extends ChangeNotifier {
  String? _pin;
  bool _isParentMode = false;
  DateTime? _lastActivity;
  static const _timeout = Duration(minutes: 10);

  bool get isPinSet => _pin != null && _pin!.isNotEmpty;
  bool get isParentMode => _isParentMode;
  String? get pin => _pin;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _pin = prefs.getString('parent_pin');
    _isParentMode = prefs.getBool('is_parent_mode') ?? false;
    if (_isParentMode) _lastActivity = DateTime.now();
    notifyListeners();
  }

  void refreshActivity() {
    _lastActivity = DateTime.now();
  }

  bool canPerformParentAction() {
    if (!isPinSet) return true;
    if (!_isParentMode) return false;
    if (_lastActivity == null) return false;
    if (DateTime.now().difference(_lastActivity!) > _timeout) {
      _isParentMode = false;
      _saveMode();
      notifyListeners();
      return false;
    }
    return true;
  }

  Future<void> setPin(String pin) async {
    _pin = pin;
    _isParentMode = true;
    _lastActivity = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('parent_pin', pin);
    await prefs.setBool('is_parent_mode', true);
    notifyListeners();
  }

  Future<void> removePin() async {
    _pin = null;
    _isParentMode = false;
    _lastActivity = null;
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

  Future<void> _saveMode() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_parent_mode', _isParentMode);
  }
}
