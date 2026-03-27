import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  bool _isError = false;
  int _attempts = 0;
  static const int _maxAttempts = 5;

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
    _shakeAnimation = Tween<double>(begin: 0, end: 24)
        .chain(CurveTween(curve: Curves.elasticIn))
        .animate(_shakeController)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _shakeController.reverse();
        }
      });

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
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
    if (_attempts >= _maxAttempts) return;
    if (_enteredPin.length >= 4) return;

    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin += digit;
      _isError = false;
    });

    _scaleController.forward().then((_) => _scaleController.reverse());

    if (_enteredPin.length == 4) {
      _verifyPin();
    }
  }

  void _onDeletePressed() {
    if (_enteredPin.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _isError = false;
    });
  }

  Future<void> _verifyPin() async {
    final pinProvider = context.read<PinProvider>();
    final isCorrect = pinProvider.verifyPin(_enteredPin);

    if (isCorrect) {
      HapticFeedback.mediumImpact();
      pinProvider.unlockParentMode();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      HapticFeedback.heavyImpact();
      _shakeController.forward(from: 0);
      setState(() {
        _isError = true;
        _attempts++;
        _enteredPin = '';
      });

      if (_attempts >= _maxAttempts) {
        Future.delayed(const Duration(seconds: 30), () {
          if (mounted) {
            setState(() {
              _attempts = 0;
            });
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: deprecated_member_use
    return WillPopScope(
      onWillPop: () async {
        Navigator.of(context).pop(false);
        return false;
      },
      child: Scaffold(
        body: AnimatedBackground(
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // ── FIXED: AnimatedBuilder → AnimatedBuilder ──
                    ScaleTransition(
                      scale: _scaleAnimation,
                      child: Icon(
                        _isError ? Icons.lock_outline : Icons.lock,
                        size: 64,
                        color: _isError ? Colors.redAccent : Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Code parental',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _attempts >= _maxAttempts
                          ? 'Trop de tentatives. Patientez 30s.'
                          : _isError
                              ? 'Code incorrect (${_maxAttempts - _attempts} essais restants)'
                              : 'Entrez votre code à 4 chiffres',
                      style: TextStyle(
                        color: _isError ? Colors.redAccent : Colors.white60,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    // ── FIXED: AnimatedBuilder → SlideTransition-style manual transform ──
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(4, (index) {
                          final isFilled = index < _enteredPin.length;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 12),
                            width: isFilled ? 20 : 16,
                            height: isFilled ? 20 : 16,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _isError
                                  ? Colors.redAccent
                                  : isFilled
                                      ? Colors.cyanAccent
                                      : Colors.white24,
                              boxShadow: isFilled && !_isError
                                  ? [
                                      BoxShadow(
                                        color: Colors.cyanAccent.withOpacity(0.5),
                                        blurRadius: 8,
                                      )
                                    ]
                                  : null,
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 48),
                    _buildKeypad(),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text(
                        'Annuler',
                        style: TextStyle(color: Colors.white60, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'del'],
    ];

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) {
                return const SizedBox(width: 80, height: 60);
              }
              return _KeyButton(
                label: key,
                onDigit: _onDigitPressed,
                onDelete: _onDeletePressed,
                disabled: _attempts >= _maxAttempts,
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final Function(String) onDigit;
  final VoidCallback onDelete;
  final bool disabled;

  const _KeyButton({
    required this.label,
    required this.onDigit,
    required this.onDelete,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDelete = label == 'del';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Focus(
        autofocus: label == '1',
        onKeyEvent: (node, event) {
          if (disabled) return KeyEventResult.ignored;
          if (event is KeyDownEvent) {
            final key = event.logicalKey;
            if (key == LogicalKeyboardKey.select ||
                key == LogicalKeyboardKey.enter ||
                key == LogicalKeyboardKey.gameButtonA ||
                key == LogicalKeyboardKey.numpadEnter) {
              if (isDelete) {
                onDelete();
              } else {
                onDigit(label);
              }
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            final hasFocus = Focus.of(context).hasFocus;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 80,
              height: 60,
              decoration: BoxDecoration(
                color: disabled
                    ? Colors.white10
                    : hasFocus
                        ? Colors.cyanAccent.withOpacity(0.2)
