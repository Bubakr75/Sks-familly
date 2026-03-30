import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// TextField optimisé TV : les flèches haut/bas déplacent le focus
/// au champ précédent/suivant au lieu de rester bloqué.
class TvTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final int maxLines;
  final bool obscureText;
  final TextInputType? keyboardType;
  final int? maxLength;
  final TextAlign textAlign;
  final TextStyle? style;
  final InputDecoration? decoration;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final Color accentColor;

  const TvTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.maxLines = 1,
    this.obscureText = false,
    this.keyboardType,
    this.maxLength,
    this.textAlign = TextAlign.start,
    this.style,
    this.decoration,
    this.onChanged,
    this.focusNode,
    this.accentColor = Colors.cyanAccent,
  });

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField>
    with SingleTickerProviderStateMixin {
  late FocusNode _focusNode;
  bool _isFocused = false;
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowAnim = Tween<double>(begin: 0.3, end: 0.8).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  void _onFocusChange() {
    setState(() => _isFocused = _focusNode.hasFocus);
    if (_focusNode.hasFocus) {
      _glowController.repeat(reverse: true);
    } else {
      _glowController.stop();
      _glowController.value = 0;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (widget.focusNode == null) _focusNode.dispose();
    _glowController.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Flèche haut → focus précédent
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      if (widget.maxLines <= 1) {
        node.previousFocus();
        return KeyEventResult.handled;
      }
    }

    // Flèche bas → focus suivant
    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      if (widget.maxLines <= 1) {
        node.nextFocus();
        return KeyEventResult.handled;
      }
    }

    // Échap ou bouton retour → quitter le champ
    if (event.logicalKey == LogicalKeyboardKey.escape ||
        event.logicalKey == LogicalKeyboardKey.goBack) {
      node.unfocus();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final defaultDecoration = InputDecoration(
      labelText: widget.labelText,
      hintText: widget.hintText,
      labelStyle: TextStyle(color: widget.accentColor.withOpacity(0.7)),
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.25)),
      counterText: '',
      filled: true,
      fillColor: _isFocused
          ? Colors.white.withOpacity(0.12)
          : Colors.white.withOpacity(0.06),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: widget.accentColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: widget.accentColor,
          width: 2,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );

    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (context, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: widget.accentColor
                          .withOpacity(_glowAnim.value * 0.25),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : [],
          ),
          child: child,
        );
      },
      child: Focus(
        onKeyEvent: _handleKeyEvent,
        child: AnimatedScale(
          scale: _isFocused ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: TextField(
            controller: widget.controller,
            focusNode: _focusNode,
            maxLines: widget.maxLines,
            obscureText: widget.obscureText,
            keyboardType: widget.keyboardType,
            maxLength: widget.maxLength,
            textAlign: widget.textAlign,
            onChanged: widget.onChanged,
            style: widget.style ??
                const TextStyle(color: Colors.white, fontSize: 16),
            decoration: widget.decoration ?? defaultDecoration,
            cursorColor: widget.accentColor,
          ),
        ),
      ),
    );
  }
}
