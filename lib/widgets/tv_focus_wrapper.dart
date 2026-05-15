import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/tv_detector.dart';

class TvFocusWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double focusBorderWidth;
  final Color focusBorderColor;
  final double borderRadius;
  final bool autofocus;
  final double focusScale;
  final double? order;

  const TvFocusWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.focusBorderWidth = 2.5,
    this.focusBorderColor = const Color(0xFF448AFF),
    this.borderRadius = 14,
    this.autofocus = false,
    this.focusScale = 1.04,
    this.order,
  });

  @override
  State<TvFocusWrapper> createState() => _TvFocusWrapperState();
}

class _TvFocusWrapperState extends State<TvFocusWrapper>
    with SingleTickerProviderStateMixin {
  bool _isFocused = false;
  late AnimationController _glowController;
  late Animation<double> _glowAnim;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _glowAnim = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  void _handleFocusChange(bool hasFocus) {
    setState(() => _isFocused = hasFocus);
    if (hasFocus) {
      _glowController.repeat(reverse: true);
    } else {
      _glowController.stop();
      _glowController.value = 0.0;
    }
  }

  KeyEventResult _handleKey(FocusNode node, RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.select ||
          event.logicalKey == LogicalKeyboardKey.enter ||
          event.logicalKey == LogicalKeyboardKey.gameButtonA ||
          event.logicalKey == LogicalKeyboardKey.numpadEnter) {
        widget.onTap?.call();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    Widget focusWidget = Focus(
      autofocus: widget.autofocus,
      onFocusChange: _handleFocusChange,
      onKey: _handleKey,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _glowAnim,
          builder: (context, child) {
            return AnimatedScale(
              scale: _isFocused ? widget.focusScale : 1.0,
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: _isFocused
                      ? Border.all(
                          color: widget.focusBorderColor.withOpacity(_glowAnim.value),
                          width: widget.focusBorderWidth,
                        )
                      : Border.all(color: Colors.transparent, width: widget.focusBorderWidth),
                  boxShadow: _isFocused
                      ? [
                          BoxShadow(
                            color: widget.focusBorderColor.withOpacity(0.2 * _glowAnim.value),
                            blurRadius: 8, spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: widget.focusBorderColor.withOpacity(0.15 * _glowAnim.value),
                            blurRadius: 20, spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(widget.borderRadius - widget.focusBorderWidth),
                  child: child,
                ),
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );

    if (widget.order != null) {
      focusWidget = FocusTraversalOrder(
        order: NumericFocusOrder(widget.order!),
        child: focusWidget,
      );
    }

    return focusWidget;
  }
}

/// TextField optimise pour TV :
/// - Bloque TOUTES les fleches directionnelles pour ne pas perdre le focus
/// - OK/Enter ouvre le clavier systeme
/// - Back ferme le clavier et rend le focus
class TvTextField extends StatefulWidget {
  final TextEditingController? controller;
  final String? labelText;
  final String? hintText;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final bool obscureText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final int? maxLength;
  final bool autofocus;
  final TextAlign textAlign;
  final TextStyle? style;
  final InputDecoration? decoration;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final int? maxLines;

  const TvTextField({
    super.key,
    this.controller,
    this.labelText,
    this.hintText,
    this.keyboardType,
    this.inputFormatters,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.maxLength,
    this.autofocus = false,
    this.textAlign = TextAlign.start,
    this.style,
    this.decoration,
    this.onSubmitted,
    this.onChanged,
    this.maxLines = 1,
  });

  @override
  State<TvTextField> createState() => _TvTextFieldState();
}

class _TvTextFieldState extends State<TvTextField> {
  late FocusNode _focusNode;
  bool _hasFocus = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      setState(() => _hasFocus = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: widget.controller,
      focusNode: _focusNode,
      keyboardType: widget.keyboardType,
      inputFormatters: widget.inputFormatters,
      obscureText: widget.obscureText,
      maxLength: widget.maxLength,
      autofocus: widget.autofocus,
      textAlign: widget.textAlign,
      maxLines: widget.maxLines,
      style: widget.style ?? const TextStyle(color: Colors.white),
      onSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      decoration: widget.decoration ?? InputDecoration(
        labelText: widget.labelText,
        hintText: widget.hintText,
        labelStyle: const TextStyle(color: Colors.white60),
        hintStyle: const TextStyle(color: Colors.white30),
        prefixIcon: widget.prefixIcon,
        suffixIcon: widget.suffixIcon,
        filled: true,
        fillColor: Colors.white10,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF448AFF), width: 2),
        ),
      ),
    );

    if (!TvDetector.isTV) return field;

    // Sur TV : intercepte TOUTES les fleches + ouvre le clavier sur OK
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _hasFocus ? const Color(0xFF00E5FF) : Colors.transparent,
          width: 2,
        ),
        boxShadow: _hasFocus
            ? [BoxShadow(color: const Color(0xFF00E5FF).withOpacity(0.3), blurRadius: 12, spreadRadius: 1)]
            : [],
      ),
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: (event) {
          if (event is RawKeyDownEvent) {
            // Bloquer les fleches pour ne pas sortir du TextField
            if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
                event.logicalKey == LogicalKeyboardKey.arrowDown ||
                event.logicalKey == LogicalKeyboardKey.arrowLeft ||
                event.logicalKey == LogicalKeyboardKey.arrowRight) {
              // Ne rien faire : empeche le focus de partir
            }
            // OK/Enter : s'assurer que le TextField a le focus et le clavier s'ouvre
            if (event.logicalKey == LogicalKeyboardKey.select ||
                event.logicalKey == LogicalKeyboardKey.enter ||
                event.logicalKey == LogicalKeyboardKey.numpadEnter) {
              if (!_focusNode.hasFocus) {
                _focusNode.requestFocus();
                SystemChannels.textInput.invokeMethod('TextInput.show');
              }
            }
          }
        },
        child: GestureDetector(
          onTap: () {
            _focusNode.requestFocus();
            SystemChannels.textInput.invokeMethod('TextInput.show');
          },
          child: AbsorbPointer(
            absorbing: false,
            child: field,
          ),
        ),
      ),
    );
  }
}

class TvFocusScope extends StatelessWidget {
  final Widget child;
  final bool autofocus;

  const TvFocusScope({
    super.key,
    required this.child,
    this.autofocus = true,
  });

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      autofocus: autofocus,
      child: FocusTraversalGroup(
        policy: OrderedTraversalPolicy(),
        child: child,
      ),
    );
  }
}

class TvKeyboardHandler extends StatelessWidget {
  final Widget child;
  const TvKeyboardHandler({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: FocusNode(),
      onKey: (_) {},
      child: Actions(
        actions: {
          ActivateIntent: _TvActivateAction(),
          ButtonActivateIntent: _TvButtonActivateAction(),
        },
        child: child,
      ),
    );
  }
}

class _TvActivateAction extends Action<ActivateIntent> {
  @override
  bool isEnabled(ActivateIntent intent) => true;
  @override
  Object? invoke(ActivateIntent intent) => null;
}

class _TvButtonActivateAction extends Action<ButtonActivateIntent> {
  @override
  bool isEnabled(ButtonActivateIntent intent) => true;
  @override
  Object? invoke(ButtonActivateIntent intent) => null;
}
