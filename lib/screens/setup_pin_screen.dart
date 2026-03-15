import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/pin_provider.dart';

class SetupPinScreen extends StatefulWidget {
  const SetupPinScreen({super.key});

  @override
  State<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends State<SetupPinScreen> with SingleTickerProviderStateMixin {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _error = false;
  late AnimationController _transitionCtrl;

  @override
  void initState() {
    super.initState();
    _transitionCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
  }

  @override
  void dispose() {
    _transitionCtrl.dispose();
    super.dispose();
  }

  void _addDigit(String digit) {
    HapticFeedback.lightImpact();
    if (!_isConfirming) {
      if (_pin.length < 4) {
        setState(() { _pin += digit; _error = false; });
        if (_pin.length == 4) {
          Future.delayed(const Duration(milliseconds: 300), () {
            _transitionCtrl.forward(from: 0);
            setState(() => _isConfirming = true);
          });
        }
      }
    } else {
      if (_confirmPin.length < 4) {
        setState(() { _confirmPin += digit; _error = false; });
        if (_confirmPin.length == 4) {
          Future.delayed(const Duration(milliseconds: 200), _validate);
        }
      }
    }
  }

  void _removeDigit() {
    HapticFeedback.lightImpact();
    setState(() {
      if (_isConfirming) {
        if (_confirmPin.isNotEmpty) {
          _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
        } else {
          _isConfirming = false;
          _pin = '';
        }
      } else {
        if (_pin.isNotEmpty) {
          _pin = _pin.substring(0, _pin.length - 1);
        }
      }
      _error = false;
    });
  }

  void _validate() {
    if (_pin == _confirmPin) {
      HapticFeedback.mediumImpact();
      context.read<PinProvider>().setPin(_pin);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Code parental defini avec succes !'),
            ],
          ),
          backgroundColor: Colors.green[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _error = true;
        _confirmPin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pinProvider = context.watch<PinProvider>();
    final currentPin = _isConfirming ? _confirmPin : _pin;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Code Parental'),
        actions: [
          if (pinProvider.isPinSet)
            TextButton.icon(
              icon: const Icon(Icons.delete_rounded, color: Colors.red, size: 18),
              label: const Text('Supprimer', style: TextStyle(color: Colors.red)),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Supprimer le code PIN ?'),
                    content: const Text('Sans code PIN, les enfants pourront modifier les scores et les reglages.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
                      FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () {
                          pinProvider.removePin();
                          Navigator.pop(ctx);
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Code parental supprime'), backgroundColor: Colors.orange),
                          );
                        },
                        child: const Text('Supprimer'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    _isConfirming ? Icons.check_circle_rounded : Icons.lock_rounded,
                    key: ValueKey(_isConfirming),
                    size: 64,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 16),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    _isConfirming ? 'Confirmer le Code' : (pinProvider.isPinSet ? 'Nouveau code PIN' : 'Definir un code PIN'),
                    key: ValueKey('$_isConfirming${pinProvider.isPinSet}'),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                if (_error)
                  const Text(
                    'Les codes ne correspondent pas',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                  ),
                if (!_error)
                  Text(
                    _isConfirming ? 'Entrez le meme code pour confirmer' : 'Choisissez un code a 4 chiffres',
                    style: const TextStyle(color: Colors.grey),
                  ),
                const SizedBox(height: 24),
                // PIN dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: i < currentPin.length ? 22 : 16,
                    height: i < currentPin.length ? 22 : 16,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < currentPin.length
                          ? (_error ? Colors.red : primary)
                          : Colors.grey.withValues(alpha: 0.3),
                      border: Border.all(color: _error ? Colors.red : primary, width: 2),
                      boxShadow: i < currentPin.length && !_error
                          ? [BoxShadow(color: primary.withValues(alpha: 0.4), blurRadius: 6)]
                          : [],
                    ),
                  )),
                ),
                // Step indicator
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 24, height: 4,
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 24, height: 4,
                      decoration: BoxDecoration(
                        color: _isConfirming ? primary : Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                _buildKeypad(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: ['1', '2', '3'].map((d) => _KeypadBtn(d, () => _addDigit(d))).toList()),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: ['4', '5', '6'].map((d) => _KeypadBtn(d, () => _addDigit(d))).toList()),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: ['7', '8', '9'].map((d) => _KeypadBtn(d, () => _addDigit(d))).toList()),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(width: 80),
          _KeypadBtn('0', () => _addDigit('0')),
          SizedBox(
            width: 80,
            height: 64,
            child: IconButton(
              icon: const Icon(Icons.backspace_rounded, size: 24),
              onPressed: _removeDigit,
            ),
          ),
        ]),
      ],
    );
  }
}

class _KeypadBtn extends StatelessWidget {
  final String digit;
  final VoidCallback onTap;
  const _KeypadBtn(this.digit, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 64,
      margin: const EdgeInsets.all(4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            ),
            child: Center(
              child: Text(digit, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ),
          ),
        ),
      ),
    );
  }
}
