import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class TvFocusWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double focusBorderWidth;
  final Color focusBorderColor;
  final BorderRadius borderRadius;

  const TvFocusWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.focusBorderWidth = 2.5,
    this.focusBorderColor = const Color(0xFF448AFF),
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA)) {
          onTap?.call();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Builder(
        builder: (context) {
          final hasFocus = Focus.of(context).hasFocus;
          return GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: hasFocus
                    ? Border.all(color: focusBorderColor, width: focusBorderWidth)
                    : Border.all(color: Colors.transparent, width: focusBorderWidth),
                boxShadow: hasFocus
                    ? [BoxShadow(color: focusBorderColor.withValues(alpha: 0.3), blurRadius: 12)]
                    : [],
              ),
              child: child,
            ),
          );
        },
      ),
    );
  }
}
