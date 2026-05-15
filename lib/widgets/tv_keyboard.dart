import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/tv_detector.dart';

/// Clavier integre pour TV navigable avec D-pad
class TvKeyboard extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onDone;
  final String title;

  const TvKeyboard({
    super.key,
    required this.controller,
    required this.onDone,
    this.title = 'Saisir du texte',
  });

  @override
  State<TvKeyboard> createState() => _TvKeyboardState();
}

class _TvKeyboardState extends State<TvKeyboard> {
  bool _isUpperCase = true;
  bool _showNumbers = false;

  List<List<String>> get _keys {
    if (_showNumbers) {
      return [
        ['1', '2', '3', '4', '5', '6', '7', '8', '9', '0'],
        ['-', '/', ':', ';', '(', ')', '\u20AC', '&', '@', '"'],
        ['.', ',', '?', '!', "'", '+', '%', '#', '=', '*'],
      ];
    }
    if (_isUpperCase) {
      return [
        ['A', 'Z', 'E', 'R', 'T', 'Y', 'U', 'I', 'O', 'P'],
        ['Q', 'S', 'D', 'F', 'G', 'H', 'J', 'K', 'L', 'M'],
        ['W', 'X', 'C', 'V', 'B', 'N'],
      ];
    }
    return [
      ['a', 'z', 'e', 'r', 't', 'y', 'u', 'i', 'o', 'p'],
      ['q', 's', 'd', 'f', 'g', 'h', 'j', 'k', 'l', 'm'],
      ['w', 'x', 'c', 'v', 'b', 'n'],
    ];
  }

  void _addChar(String char) {
    final ctrl = widget.controller;
    final text = ctrl.text;
    final sel = ctrl.selection;
    final newText = text.substring(0, sel.start) + char + text.substring(sel.end);
    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: sel.start + char.length),
    );
  }

  void _backspace() {
    final ctrl = widget.controller;
    final text = ctrl.text;
    final sel = ctrl.selection;
    if (sel.start > 0) {
      final newText = text.substring(0, sel.start - 1) + text.substring(sel.end);
      ctrl.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: sel.start - 1),
      );
    }
  }

  void _addSpace() => _addChar(' ');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1B2A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titre + champ de texte
          Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF00E5FF), width: 2),
            ),
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: widget.controller,
              builder: (_, value, __) => Text(
                value.text.isEmpty ? '...' : value.text,
                style: TextStyle(
                  color: value.text.isEmpty ? Colors.white30 : Colors.white,
                  fontSize: 24, fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Lignes de touches
          ..._keys.asMap().entries.map((row) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row.value.map((key) => _KeyButton(
                label: key,
                autofocus: row.key == 0 && key == _keys[0][0],
                onTap: () => _addChar(key),
              )).toList(),
            ),
          )),
          const SizedBox(height: 4),
          // Ligne du bas : actions
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ActionButton(
                icon: Icons.keyboard_capslock,
                label: _isUpperCase ? 'min' : 'MAJ',
                color: Colors.orangeAccent,
                onTap: () => setState(() => _isUpperCase = !_isUpperCase),
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.onetwothree,
                label: _showNumbers ? 'ABC' : '123',
                color: Colors.purpleAccent,
                onTap: () => setState(() => _showNumbers = !_showNumbers),
              ),
              const SizedBox(width: 8),
              _KeyButton(
                label: 'ESPACE',
                width: 200,
                onTap: _addSpace,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.backspace_outlined,
                label: 'Effacer',
                color: Colors.redAccent,
                onTap: _backspace,
              ),
              const SizedBox(width: 8),
              _ActionButton(
                icon: Icons.check_circle,
                label: 'OK',
                color: const Color(0xFF00E5FF),
                onTap: widget.onDone,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeyButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final double? width;
  final bool autofocus;

  const _KeyButton({
    required this.label,
    required this.onTap,
    this.width,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Focus(
        autofocus: autofocus,
        onFocusChange: (_) {},
        onKey: (node, event) {
          if (event is RawKeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA) {
              onTap();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            final hasFocus = Focus.of(context).hasFocus;
            return GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: width ?? 52,
                height: 52,
                decoration: BoxDecoration(
                  color: hasFocus ? const Color(0xFF00E5FF).withOpacity(0.3) : Colors.white12,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasFocus ? const Color(0xFF00E5FF) : Colors.white24,
                    width: hasFocus ? 2.5 : 1,
                  ),
                  boxShadow: hasFocus
                      ? [BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.3), blurRadius: 8)]
                      : [],
                ),
                child: Center(
                  child: Text(label,
                    style: TextStyle(
                      color: hasFocus ? Colors.white : Colors.white70,
                      fontSize: label.length > 2 ? 13 : 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Focus(
        onKey: (node, event) {
          if (event is RawKeyDownEvent) {
            if (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter ||
                event.logicalKey == LogicalKeyboardKey.gameButtonA) {
              onTap();
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Builder(
          builder: (context) {
            final hasFocus = Focus.of(context).hasFocus;
            return GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: hasFocus ? color.withOpacity(0.3) : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasFocus ? color : color.withOpacity(0.3),
                    width: hasFocus ? 2.5 : 1,
                  ),
                  boxShadow: hasFocus
                      ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8)]
                      : [],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(icon, color: color, size: 20),
                  const SizedBox(width: 6),
                  Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
                ]),
              ),
            );
          },
        ),
      ),
    );
  }
}
