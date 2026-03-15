import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/pin_provider.dart';

class PinVerificationScreen extends StatefulWidget {
  final VoidCallback onVerified;
  const PinVerificationScreen({super.key, required this.onVerified});
  @override
  State<PinVerificationScreen> createState() => _PinVerificationScreenState();
}

class _PinVerificationScreenState extends State<PinVerificationScreen> with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  bool _error = false;
  int _attempts = 0;
  late AnimationController _shakeCtrl;

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
  }

  @override
  void dispose() {
    _shakeCtrl.dispose();
    super.dispose();
  }

  void _addDigit(String digit) {
    if (_enteredPin.length < 4) {
      HapticFeedback.lightImpact();
      setState(() {
        _enteredPin += digit;
        _error = false;
      });
      if (_enteredPin.length == 4) {
        Future.delayed(const Duration(milliseconds: 200), _verify);
      }
    }
  }

  void _removeDigit() {
    if (_enteredPin.isNotEmpty) {
      HapticFeedback.lightImpact();
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _error = false;
      });
    }
  }

  void _verify() {
    final pin = context.read<PinProvider>();
    if (pin.verifyPin(_enteredPin)) {
      HapticFeedback.mediumImpact();
      widget.onVerified();
    } else {
      HapticFeedback.heavyImpact();
      _shakeCtrl.forward(from: 0);
      _attempts++;
      setState(() {
        _error = true;
        _enteredPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF0A110B), const Color(0xFF162118)]
                : [const Color(0xFFF5F7F5), Colors.white],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Spacer(flex: 2),
              // Lock icon with animation
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.8, end: 1.0),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (_, v, child) => Transform.scale(scale: v, child: child),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [primary, Theme.of(context).colorScheme.secondary]),
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
                  ),
                  child: const Icon(Icons.lock_rounded, size: 44, color: Colors.white),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Code Parental', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  _error
                      ? (_attempts >= 3 ? 'Trop de tentatives, reessayez' : 'Code incorrect, reessayez')
                      : 'Entrez votre code a 4 chiffres',
                  key: ValueKey('$_error$_attempts'),
                  style: TextStyle(color: _error ? Colors.red : Colors.grey, fontSize: 14),
                ),
              ),
              const SizedBox(height: 32),
              // PIN dots with shake animation
              AnimatedBuilder(
                animation: _shakeCtrl,
                builder: (_, child) {
                  final dx = _shakeCtrl.isAnimating
                      ? ((_shakeCtrl.value * 8).truncate() % 2 == 0 ? 8.0 : -8.0) * (1 - _shakeCtrl.value)
                      : 0.0;
                  return Transform.translate(offset: Offset(dx, 0), child: child);
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: i < _enteredPin.length ? 22 : 16,
                    height: i < _enteredPin.length ? 22 : 16,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _error
                          ? Colors.red
                          : i < _enteredPin.length
                              ? primary
                              : Colors.transparent,
                      border: Border.all(
                        color: _error ? Colors.red : primary,
                        width: 2.5,
                      ),
                      boxShadow: i < _enteredPin.length && !_error
                          ? [BoxShadow(color: primary.withValues(alpha: 0.4), blurRadius: 8)]
                          : [],
                    ),
                  )),
                ),
              ),
              const Spacer(flex: 1),
              // Keypad
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 48),
                child: Column(
                  children: [
                    _buildRow(['1', '2', '3']),
                    _buildRow(['4', '5', '6']),
                    _buildRow(['7', '8', '9']),
                    Row(
                      children: [
                        const Expanded(child: SizedBox(height: 72)),
                        Expanded(child: _KeyButton(label: '0', onTap: () => _addDigit('0'))),
                        Expanded(
                          child: SizedBox(
                            height: 72,
                            child: IconButton(
                              icon: const Icon(Icons.backspace_outlined, size: 26),
                              onPressed: _removeDigit,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(List<String> digits) {
    return Row(
      children: digits.map((d) => Expanded(child: _KeyButton(label: d, onTap: () => _addDigit(d)))).toList(),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _KeyButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(36),
          onTap: onTap,
          child: Center(
            child: Text(label, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
  }
}
