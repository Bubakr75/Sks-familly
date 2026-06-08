import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;

class TvFocusWrapper extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double focusBorderWidth;
  final Color focusBorderColor;
  final double borderRadius;
  final bool autofocus;
  final double focusScale;

  const TvFocusWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.focusBorderWidth = 2.5,
    this.focusBorderColor = const Color(0xFF448AFF),
    this.borderRadius = 14,
    this.autofocus = false,
    this.focusScale = 1.04,
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
    return Focus(
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
                          // Inner glow
                          BoxShadow(
                            color: widget.focusBorderColor
                                .withOpacity(0.2 * _glowAnim.value),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                          // Outer glow
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
  }
}

/// Keyboard handler pour la racine de l'app TV
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
