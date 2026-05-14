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
                          color: widget.focusBorderColor
                              .withOpacity(_glowAnim.value),
                          width: widget.focusBorderWidth,
                        )
                      : Border.all(
                          color: Colors.transparent,
                          width: widget.focusBorderWidth,
                        ),
                  boxShadow: _isFocused
                      ? [
                          BoxShadow(
                            color: widget.focusBorderColor
                                .withOpacity(0.2 * _glowAnim.value),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                          BoxShadow(
                            color: widget.focusBorderColor
                                .withOpacity(0.15 * _glowAnim.value),
                            blurRadius: 20,
                            spreadRadius: 2,
                          ),
                        ]
                      : [],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                      widget.borderRadius - widget.focusBorderWidth),
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

/// Wrapper pour TextField sur TV : empeche le D-pad de sortir du champ
class TvTextField extends StatelessWidget {
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
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      obscureText: obscureText,
      maxLength: maxLength,
      autofocus: autofocus,
      textAlign: textAlign,
      maxLines: maxLines,
      style: style ?? const TextStyle(color: Colors.white),
      onSubmitted: onSubmitted,
      decoration: decoration ?? InputDecoration(
        labelText: labelText,
        hintText: hintText,
        labelStyle: const TextStyle(color: Colors.white60),
        hintStyle: const TextStyle(color: Colors.white30),
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
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

    // Sur TV : intercepte les fleches haut/bas pour ne pas sortir du champ
    return Focus(
      onKey: (node, event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
              event.logicalKey == LogicalKeyboardKey.arrowDown) {
            // Sur TV, on bloque la sortie du TextField avec haut/bas
            // L'utilisateur doit appuyer sur Enter/Back pour quitter le champ
            return KeyEventResult.handled;
          }
        }
        return KeyEventResult.ignored;
      },
      child: field,
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
