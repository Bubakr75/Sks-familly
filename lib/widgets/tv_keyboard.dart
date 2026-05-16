import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  int _focusRow = 0;
  int _focusCol = 0;
  late FocusNode _rootFocus;

  List<List<String>> get _keys {
    if (_showNumbers) {
      return [
        ['1','2','3','4','5','6','7','8','9','0'],
        ['-','/',':',';','(',')','€','&','@','"'],
        ['.',',','?','!',"'",'+','%','#','=','*'],
      ];
    }
    if (_isUpperCase) {
      return [
        ['A','Z','E','R','T','Y','U','I','O','P'],
        ['Q','S','D','F','G','H','J','K','L','M'],
        ['W','X','C','V','B','N'],
      ];
    }
    return [
      ['a','z','e','r','t','y','u','i','o','p'],
      ['q','s','d','f','g','h','j','k','l','m'],
      ['w','x','c','v','b','n'],
    ];
  }

  static const _actionLabels = ['MAJ','123','ESPACE','EFFACER','OK'];
  int get _totalRows => _keys.length + 1;
  int _colsForRow(int row) => row < _keys.length ? _keys[row].length : _actionLabels.length;

  @override
  void initState() {
    super.initState();
    _rootFocus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _rootFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _rootFocus.dispose();
    super.dispose();
  }

  void _addChar(String char) {
    final ctrl = widget.controller;
    final text = ctrl.text;
    final sel = ctrl.selection;
    final start = sel.start < 0 ? text.length : sel.start;
    final end = sel.end < 0 ? text.length : sel.end;
    final newText = text.substring(0, start) + char + text.substring(end);
    ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + char.length),
    );
  }

  void _backspace() {
    final ctrl = widget.controller;
    final text = ctrl.text;
    if (text.isNotEmpty) {
      final sel = ctrl.selection;
      final start = sel.start < 0 ? text.length : sel.start;
      if (start > 0) {
        final newText = text.substring(0, start - 1) + text.substring(start);
        ctrl.value = TextEditingValue(
          text: newText,
          selection: TextSelection.collapsed(offset: start - 1),
        );
      }
    }
  }

  void _onAction(int row, int col) {
    if (row < _keys.length) {
      _addChar(_keys[row][col]);
    } else {
      switch (col) {
        case 0: setState(() => _isUpperCase = !_isUpperCase); break;
        case 1: setState(() { _showNumbers = !_showNumbers; _focusRow = 0; _focusCol = 0; }); break;
        case 2: _addChar(' '); break;
        case 3: _backspace(); break;
        case 4: widget.onDone(); break;
      }
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _focusRow = (_focusRow + 1).clamp(0, _totalRows - 1);
        _focusCol = _focusCol.clamp(0, _colsForRow(_focusRow) - 1);
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _focusRow = (_focusRow - 1).clamp(0, _totalRows - 1);
        _focusCol = _focusCol.clamp(0, _colsForRow(_focusRow) - 1);
      });
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      setState(() => _focusCol = (_focusCol + 1) % _colsForRow(_focusRow));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      setState(() => _focusCol = (_focusCol - 1 + _colsForRow(_focusRow)) % _colsForRow(_focusRow));
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.gameButtonA) {
      _onAction(_focusRow, _focusCol);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.browserBack) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _rootFocus,
      onKeyEvent: _handleKeyEvent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF0D1B2A),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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
            ..._buildKeyRows(),
            const SizedBox(height: 8),
            _buildActionRow(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildKeyRows() {
    final keys = _keys;
    return List.generate(keys.length, (row) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(keys[row].length, (col) {
            final focused = _focusRow == row && _focusCol == col;
            return _buildKey(keys[row][col], focused, null, false);
          }),
        ),
      );
    });
  }

  Widget _buildActionRow() {
    final row = _keys.length;
    final colors = [Colors.orangeAccent, Colors.purpleAccent, Colors.white70, Colors.redAccent, const Color(0xFF00E5FF)];
    final icons = [Icons.keyboard_capslock, Icons.onetwothree, null, Icons.backspace_outlined, Icons.check_circle];

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(_actionLabels.length, (col) {
        final focused = _focusRow == row && _focusCol == col;
        return Padding(
          padding: const EdgeInsets.all(3),
          child: GestureDetector(
            onTap: () => _onAction(row, col),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: focused ? colors[col].withOpacity(0.3) : colors[col].withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: focused ? colors[col] : colors[col].withOpacity(0.3),
                  width: focused ? 2.5 : 1,
                ),
                boxShadow: focused ? [BoxShadow(color: colors[col].withOpacity(0.4), blurRadius: 10)] : [],
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icons[col] != null) ...[
                  Icon(icons[col], color: colors[col], size: 20),
                  const SizedBox(width: 6),
                ],
                Text(
                  col == 0 ? (_isUpperCase ? 'min' : 'MAJ') : (col == 1 ? (_showNumbers ? 'ABC' : '123') : _actionLabels[col]),
                  style: TextStyle(color: colors[col], fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildKey(String label, bool focused, Color? bgColor, bool wide) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: GestureDetector(
        onTap: () => _addChar(label),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: wide ? 120 : 52,
          height: 52,
          decoration: BoxDecoration(
            color: focused ? const Color(0xFF00E5FF).withOpacity(0.3) : (bgColor ?? Colors.white12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: focused ? const Color(0xFF00E5FF) : Colors.white24,
              width: focused ? 2.5 : 1,
            ),
            boxShadow: focused ? [BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.4), blurRadius: 10)] : [],
          ),
          child: Center(
            child: Text(label,
              style: TextStyle(
                color: focused ? Colors.white : Colors.white70,
                fontSize: 20,
                fontWeight: focused ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
