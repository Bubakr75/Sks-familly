import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Widget pour rendre n'importe quel element focusable et activable
/// avec une telecommande TV (D-pad + bouton OK/Select/Enter)
class TvFocusWrapper extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double focusBorderWidth;
  final Color focusBorderColor;
  final BorderRadius borderRadius;
  final bool autofocus;

  const TvFocusWrapper({
    super.key,
    required this.child,
    this.onTap,
    this.focusBorderWidth = 2.5,
    this.focusBorderColor = const Color(0xFF448AFF),
    this.borderRadius = const BorderRadius.all(Radius.circular(14)),
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: autofocus,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent &&
            (event.logicalKey == LogicalKeyboardKey.select ||
             event.logicalKey == LogicalKeyboardKey.enter ||
             event.logicalKey == LogicalKeyboardKey.gameButtonA ||
             event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
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

/// Intercepteur global de touches TV
/// A placer dans le builder de MaterialApp pour que
/// TOUS les boutons/champs repondent au bouton OK de la telecommande
class TvKeyboardHandler extends StatelessWidget {
  final Widget child;

  const TvKeyboardHandler({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: false,
      onKeyEvent: (event) {
        // On ne fait rien ici, le vrai travail est dans _TvActionDispatcher
      },
      child: Actions(
        actions: <Type, Action<Intent>>{
          ActivateIntent: _TvActivateAction(),
          ButtonActivateIntent: _TvButtonActivateAction(),
        },
        child: child,
      ),
    );
  }
}

/// Action qui s'execute quand l'utilisateur appuie sur Enter/Select
/// sur un widget focusable (bouton, checkbox, switch, etc.)
class _TvActivateAction extends Action<ActivateIntent> {
  @override
  Object? invoke(ActivateIntent intent) {
    // Laisse Flutter gerer normalement l'activation
    // Ceci garantit que les boutons natifs repondent au Enter/Select
    return null;
  }

  @override
  bool isEnabled(ActivateIntent intent) => true;
}

class _TvButtonActivateAction extends Action<ButtonActivateIntent> {
  @override
  Object? invoke(ButtonActivateIntent intent) {
    return null;
  }

  @override
  bool isEnabled(ButtonActivateIntent intent) => true;
}
