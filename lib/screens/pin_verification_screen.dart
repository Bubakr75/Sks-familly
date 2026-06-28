import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/pin_provider.dart';
import '../config/emerald_theme.dart';

class PinVerificationScreen extends StatefulWidget {
  const PinVerificationScreen({super.key});

  @override
  State<PinVerificationScreen> createState() => _PinVerificationScreenState();
}

class _PinVerificationScreenState extends State<PinVerificationScreen>
    with TickerProviderStateMixin {
  String _enteredPin = '';
  bool _hasError = false;
  Timer? _lockoutTimer;
  int _lockoutSeconds = 0;

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

    // Vérifier si déjà bloqué au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialLockout();
    });
  }

  void _checkInitialLockout() {
    final pin = context.read<PinProvider>();
    if (pin.isLockedOut) {
      setState(() {
        _lockoutSeconds = pin.lockoutRemainingSeconds;
      });
      _startLockoutTimer();
    }
  }

  void _startLockoutTimer() {
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final pin = context.read<PinProvider>();
      if (!pin.isLockedOut) {
        timer.cancel();
        setState(() {
          _lockoutSeconds = 0;
          _hasError = false;
        });
      } else {
        setState(() {
          _lockoutSeconds = pin.lockoutRemainingSeconds;
        });
      }
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _scaleController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _onDigitPressed(String digit) {
    if (_lockoutSeconds > 0 || _enteredPin.length >= 4) return;
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
    if (_lockoutSeconds > 0 || _enteredPin.isEmpty) return;
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _hasError = false;
    });
  }

  void _verifyPin() {
    final pinProvider = context.read<PinProvider>();
    final ok = pinProvider.verifyPin(_enteredPin);

    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _hasError = true;
        _enteredPin = '';
      });
      _shakeController.forward().then((_) => _shakeController.reset());

      // Vérifier si le provider a déclenché un lockout
      if (pinProvider.isLockedOut) {
        setState(() {
          _lockoutSeconds = pinProvider.lockoutRemainingSeconds;
        });
        _startLockoutTimer();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = _hasError
        ? EmeraldPalette.error
        : (_lockoutSeconds > 0 ? EmeraldPalette.warning : EmeraldPalette.gold);

    return EmeraldBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),
                // Icône
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withValues(alpha: 0.12),
                    border: Border.all(
                        color: accent.withValues(alpha: 0.4), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: accent.withValues(alpha: 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    _lockoutSeconds > 0
                        ? Icons.lock_clock_rounded
                        : Icons.shield_rounded,
                    size: 56,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _lockoutSeconds > 0
                      ? 'Compte bloqué'
                      : _hasError
                          ? 'Code incorrect'
                          : 'Code parental requis',
                  textAlign: TextAlign.center,
                  style: EmeraldTypography.heading.copyWith(
                    fontSize: 20,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _lockoutSeconds > 0
                      ? 'Réessayez dans $_lockoutSeconds s'
                      : _hasError
                          ? 'Code incorrect, réessayez'
                          : 'Entrez le code à 4 chiffres',
                  textAlign: TextAlign.center,
                  style: EmeraldTypography.caption.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 32),
                // PIN dots
                AnimatedBuilder(
                  animation: _shakeAnimation,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(
                        _shakeAnimation.value *
                            ((_shakeController.value * 10).toInt().isEven
                                ? 1
                                : -1),
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
                            color: isFilled ? accent : Colors.transparent,
                            border: Border.all(
                              color: accent.withValues(alpha: 0.6),
                              width: 2,
                            ),
                            boxShadow: isFilled
                                ? [
                                    BoxShadow(
                                      color: accent.withValues(alpha: 0.4),
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
                  child: _buildKeypad(accent),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Annuler',
                    style: EmeraldTypography.caption.copyWith(fontSize: 16),
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

  Widget _buildKeypad(Color accent) {
    final keys = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'DEL'],
    ];
    final isDisabled = _lockoutSeconds > 0;

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((row) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: row.map((key) {
            if (key.isEmpty) return const SizedBox(width: 72, height: 72);
            return _KeyButton(
              label: key,
              accent: accent,
              onTap: key == 'DEL' ? _onDeletePressed : () => _onDigitPressed(key),
              isDisabled: isDisabled,
            );
          }).toList(),
        );
      }).toList(),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final Color accent;
  final VoidCallback onTap;
  final bool isDisabled;

  const _KeyButton({
    required this.label,
    required this.accent,
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
            color: isDisabled
                ? EmeraldPalette.surfaceLow
                : EmeraldPalette.surface,
            border: Border.all(
              color: isDisabled
                  ? EmeraldPalette.glassBorder
                  : accent.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Center(
            child: label == 'DEL'
                ? Icon(
                    Icons.backspace_outlined,
                    color: isDisabled
                        ? EmeraldPalette.textMuted
                        : EmeraldPalette.textSecondary,
                    size: 24,
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: isDisabled
                          ? EmeraldPalette.textMuted
                          : EmeraldPalette.textPrimary,
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
