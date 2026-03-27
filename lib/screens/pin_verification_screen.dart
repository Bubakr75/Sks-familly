import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/pin_provider.dart';
import '../widgets/animated_background.dart';

class PinVerificationScreen extends StatefulWidget {
  const PinVerificationScreen({super.key});

  @override
  State<PinVerificationScreen> createState() => _PinVerificationScreenState();
}

class _PinVerificationScreenState extends State<PinVerificationScreen>
    with TickerProviderStateMixin {
  String _enteredPin = '';
  bool _hasError = false;
  int _attempts = 0;
  static const int _maxAttempts = 5;
  bool _isLocked = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 24).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_isLocked || _enteredPin.length >= 4) return;
    setState(() {
      _enteredPin += digit;
      _hasError = false;
    });
    _scaleController.forward().then((_) => _scaleController.reverse());

    if (_enteredPin.length == 4) {
      _verifyPin();
    }
  }

  void _onDeletePressed() {
    if (_isLocked || _enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _hasError = false;
    });
  }

  void _verifyPin() {
    final pinProvider = context.read<PinProvider>();
    if (pinProvider.verifyPin(_enteredPin)) {
      pinProvider.unlockParentMode();
      Navigator.pop(context, true);
    } else {
      _attempts++;
      setState(() {
        _hasError = true;
        _enteredPin = '';
      });
      _shakeController.forward().then((_) => _shakeController.reset());

      if (_attempts >= _maxAttempts) {
        setState(() => _isLocked = true);
        Future.delayed(const Duration(seconds: 30), () {
          if (mounted) {
            setState(() {
              _isLocked = false;
              _attempts = 0;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lockColor = _hasError ? Colors.redAccent : Colors.cyanAccent;

    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Lock icon
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  child: Icon(
                    _isLocked ? Icons.lock_clock : Icons.lock_outline,
                    size: 64,
                    color: lockColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isLocked
                      ? 'Trop de tentatives\nRéessayez dans 30s'
                      : _hasError
                          ? 'Code incorrect'
                          : 'Entrez le code parental',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _hasError ? Colors.redAccent : Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 32),
                // PIN dots
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        _shakeAnimation.value *
                            ((_shakeController.value * 10).toInt().isEven ? 1 : -1),
                        0,
                      ),
                      child: child,
                    );
                  },
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final isFilled = index < _enteredPin.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isFilled ? lockColor : Colors.transparent,
                            border: Border.all(
                              color: lockColor.withOpacity(0.6),
                              width: 2,
                            ),
                            boxShadow: isFilled
                                ? [
                                    BoxShadow(
                                      color: lockColor.withOpacity(0.4),
                                      blurRadius: 8,
                                    )
                                  ]
                                : null,
                          ),
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 48),
                // Keypad
                Expanded(
                  flex: 5,
                  child: _buildKeypad(),
                ),
                // Cancel button
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    'Annuler',
                    style: TextStyle(color: Colors.white54, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'DEL'],
    ];

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: row.map((key) {
            if (key.isEmpty) return const SizedBox(width: 72, height: 72);
            return _KeyButton(
              label: key,
              onTap: key == 'DEL' ? _onDeletePressed : () => _onDigitPressed(key),
              isDisabled: _isLocked,
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDisabled;

  const _KeyButton({
    required this.label,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.select ||
                  event.logicalKey == LogicalKeyboardKey.enter)) {
            if (!isDisabled) onTap();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(isDisabled ? 0.02 : 0.06),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Center(
            child: label == 'DEL'
                ? Icon(
                    Icons.backspace_outlined,
                    color: isDisabled ? Colors.white24 : Colors.white70,
                    size: 24,
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: isDisabled ? Colors.white24 : Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
